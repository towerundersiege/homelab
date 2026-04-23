from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path
from shutil import which
from typing import Any

import click
import yaml


ROOT_DIR = Path(__file__).resolve().parent
PASS_STORE_DIR = Path(os.environ.get("HOMELAB_PASSWORD_STORE_DIR", ROOT_DIR / ".homelab-pass"))
PASS_PREFIX = os.environ.get("HOMELAB_PASS_PREFIX", "homelab")
ANSIBLE_DIR = ROOT_DIR / "ansible"
TERRAFORM_DIR = ROOT_DIR / "terraform"
INVENTORY_PATH = ANSIBLE_DIR / "inventories" / "lab" / "hosts.yml"
GROUP_VARS_PATH = ANSIBLE_DIR / "inventories" / "lab" / "group_vars" / "all.yml"
TFVARS_PATH = TERRAFORM_DIR / "terraform.tfvars"
SECRETS_RENDER_SCRIPT = ROOT_DIR / "scripts" / "render-secrets.sh"
SECRETS_INIT_SCRIPT = ROOT_DIR / "scripts" / "init-homelab-pass.sh"
SSH_KEYS_DIR = ROOT_DIR / "keys" / "ssh"
KUBECONFIG_DIR = ROOT_DIR / "kubeconfig"


def env_with_pass() -> dict[str, str]:
    env = os.environ.copy()
    env["PASSWORD_STORE_DIR"] = str(PASS_STORE_DIR)
    return env


def run(
    cmd: list[str],
    *,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    check: bool = True,
    capture_output: bool = False,
    input_text: str | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        env=env,
        check=check,
        text=True,
        input=input_text,
        stdout=subprocess.PIPE if capture_output else None,
        stderr=subprocess.PIPE if capture_output else None,
    )


def require_tool(name: str) -> None:
    if which(name) is None:
        raise click.ClickException(f"missing required command: {name}")


def load_yaml(path: Path) -> dict[str, Any]:
    with path.open() as fh:
        data = yaml.safe_load(fh)
    return data or {}


def inventory_data() -> tuple[dict[str, Any], dict[str, Any]]:
    return load_yaml(INVENTORY_PATH), load_yaml(GROUP_VARS_PATH)


def flatten_hosts() -> dict[str, dict[str, Any]]:
    inventory, _ = inventory_data()
    hosts: dict[str, dict[str, Any]] = {}

    def walk(node: dict[str, Any]) -> None:
        for name, data in (node.get("hosts") or {}).items():
            hosts[name] = data or {}
        for child in (node.get("children") or {}).values():
            walk(child or {})

    walk(inventory.get("all", {}))
    return hosts


def host_group_map() -> dict[str, str]:
    inventory, _ = inventory_data()
    mapping: dict[str, str] = {}

    def walk(node_name: str, node: dict[str, Any]) -> None:
        for name in (node.get("hosts") or {}).keys():
            mapping[name] = node_name
        for child_name, child in (node.get("children") or {}).items():
            walk(child_name, child or {})

    for child_name, child in (inventory.get("all", {}).get("children") or {}).items():
        walk(child_name, child or {})
    return mapping


def parse_vm_definitions() -> dict[str, dict[str, Any]]:
    text = TFVARS_PATH.read_text()
    match = re.search(r"vm_definitions\s*=\s*\{(?P<body>.*)\n\}", text, re.S)
    if not match:
        return {}

    body = match.group("body")
    blocks = re.finditer(r"(?m)^\s*([A-Za-z0-9_-]+)\s*=\s*\{(.*?)^\s*\}", body, re.S | re.M)
    parsed: dict[str, dict[str, Any]] = {}

    for block in blocks:
        name = block.group(1)
        raw = block.group(2)
        data: dict[str, Any] = {}

        for key in ["vm_id", "role", "ip_address", "cidr", "cpu_cores", "memory_mb", "disk_gb"]:
            item = re.search(rf"(?m)^\s*{re.escape(key)}\s*=\s*(.+?)\s*$", raw)
            if not item:
                continue
            value = item.group(1).rstrip(",").strip()
            if value.isdigit():
                data[key] = int(value)
            else:
                data[key] = value.strip('"')

        tags = re.search(r"tags\s*=\s*\[(.*?)\]", raw, re.S)
        if tags:
            data["tags"] = re.findall(r'"([^"]+)"', tags.group(1))

        parsed[name] = data

    return parsed


def cluster_name(group_vars: dict[str, Any]) -> str:
    root = str(group_vars.get("proxmox_storage_k8s_root") or group_vars.get("shared_storage_k8s_root") or "")
    match = re.search(r"/k8s/([^/]+)$", root)
    return match.group(1) if match else "lyonesse"


def dns_record_map(group_vars: dict[str, Any]) -> dict[str, str]:
    return {record["domain"]: record["ip"] for record in group_vars.get("pihole_dns_records", [])}


def cluster_info_map() -> dict[str, dict[str, Any]]:
    hosts = flatten_hosts()
    groups = host_group_map()
    _, group_vars = inventory_data()
    name = cluster_name(group_vars)
    records = dns_record_map(group_vars)
    api_domain = f"api.{name}.k8s.towerundersiege.com"
    ingress_domain = f"ingress.{name}.k8s.towerundersiege.com"

    control_plane = sorted(host for host, group in groups.items() if group == "k3s_control_plane")
    workers = sorted(host for host, group in groups.items() if group == "k3s_workers")

    return {
        name: {
            "name": name,
            "api_domain": api_domain,
            "api_ip": records.get(api_domain, group_vars.get("k3s_api_endpoint")),
            "ingress_domain": ingress_domain,
            "ingress_ip": records.get(ingress_domain, group_vars.get("cilium_ingress_lb_ip")),
            "control_plane": control_plane,
            "workers": workers,
            "hosts": [host for host in [*control_plane, *workers] if host in hosts],
        }
    }


def pass_path(key: str) -> str:
    return f"{PASS_PREFIX}/{key}"


def pass_get(key: str) -> str:
    require_tool("pass")
    result = run(["pass", "show", pass_path(key)], env=env_with_pass(), capture_output=True)
    return (result.stdout or "").splitlines()[0]


def pass_set(key: str, value: str) -> None:
    require_tool("pass")
    run(
        ["pass", "insert", "-m", "-f", pass_path(key)],
        env=env_with_pass(),
        input_text=f"{value}\n",
    )


def primary_control_plane(cluster: str) -> str:
    info = cluster_info_map().get(cluster)
    if not info or not info["control_plane"]:
        raise click.ClickException(f"cluster {cluster} has no control-plane node in inventory")
    return info["control_plane"][0]


def resolve_host(name: str) -> tuple[str, dict[str, Any]]:
    hosts = flatten_hosts()
    aliases = {"proxmox": "cornwall"}
    resolved = aliases.get(name, name)
    if resolved not in hosts:
        raise click.ClickException(f"unknown host: {name}")
    return resolved, hosts[resolved]


def host_connection(name: str) -> tuple[str, dict[str, Any], dict[str, Any], str]:
    resolved, host = resolve_host(name)
    _, group_vars = inventory_data()
    user = host.get("ansible_user") or group_vars["ansible_user"]
    return resolved, host, group_vars, user


def ssh_identity_config(host_name: str, identity: str) -> tuple[dict[str, Any], str, str]:
    resolved, host, _, automation_user = host_connection(host_name)

    if identity == "automation":
        key_file = host.get("ansible_ssh_private_key_file")
        user = automation_user
    elif identity == "ryan":
        key_file = host.get("ssh_private_key_file") or host.get("ansible_ssh_private_key_file")
        user = host.get("ssh_user") or ("root" if resolved == "cornwall" else "ryan")
    else:
        raise click.ClickException(f"unsupported ssh identity: {identity}")

    if not key_file:
        raise click.ClickException(f"host {host_name} has no SSH key configured for identity {identity}")

    return host, user, key_file


def ssh_command(
    host_name: str,
    remote_args: list[str] | None = None,
    *,
    identity: str = "automation",
    allocate_tty: bool = False,
    disable_host_key_checking: bool = True,
) -> list[str]:
    host, user, key_file = ssh_identity_config(host_name, identity)

    cmd = ["ssh"]
    if disable_host_key_checking:
        cmd.extend(["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"])
    cmd.extend(["-i", key_file])
    if allocate_tty:
        cmd.append("-t")
    cmd.append(f"{user}@{host['ansible_host']}")
    if remote_args:
        cmd.extend(remote_args)
    return cmd


def ssh_exec(host_name: str, remote_args: list[str], *, identity: str = "automation", allocate_tty: bool = False) -> None:
    cmd = ssh_command(host_name, remote_args, identity=identity, allocate_tty=allocate_tty)
    os.execvp(cmd[0], cmd)


def ssh_capture(host_name: str, remote_args: list[str]) -> str:
    result = run(ssh_command(host_name, remote_args, identity="automation"), capture_output=True)
    return result.stdout or ""


def local_kubeconfig_path(cluster: str) -> Path:
    return KUBECONFIG_DIR / f"{cluster}.yaml"


def sync_kubeconfig(cluster: str) -> Path:
    info = cluster_info_map().get(cluster)
    if not info:
        raise click.ClickException(f"unknown cluster: {cluster}")

    raw = ssh_capture(primary_control_plane(cluster), ["sudo", "cat", "/etc/rancher/k3s/k3s.yaml"])
    data = yaml.safe_load(raw)
    if not data:
        raise click.ClickException(f"failed to load kubeconfig from {cluster}")

    data["clusters"][0]["cluster"]["server"] = f"https://{info['api_ip']}:6443"
    KUBECONFIG_DIR.mkdir(parents=True, exist_ok=True)
    path = local_kubeconfig_path(cluster)
    path.write_text(yaml.safe_dump(data, sort_keys=False))
    path.chmod(0o600)
    return path


def ensure_local_kubeconfig(cluster: str, *, refresh: bool = False) -> Path:
    path = local_kubeconfig_path(cluster)
    if refresh or not path.exists():
        return sync_kubeconfig(cluster)
    return path


def render_secrets() -> None:
    run([str(SECRETS_RENDER_SCRIPT)], cwd=ROOT_DIR, env=env_with_pass())


def terraform_init() -> None:
    run(["terraform", "init"], cwd=TERRAFORM_DIR)


def terraform_plan() -> None:
    run(["terraform", "plan"], cwd=TERRAFORM_DIR)


def terraform_apply(*, auto_approve: bool) -> None:
    cmd = ["terraform", "apply"]
    if auto_approve:
        cmd.append("-auto-approve")
    run(cmd, cwd=TERRAFORM_DIR)


def install_ansible_collections() -> None:
    run(["ansible-galaxy", "collection", "install", "-r", "requirements.yml"], cwd=ANSIBLE_DIR)


def run_ansible_playbook(playbook: str, extra_args: tuple[str, ...] = ()) -> None:
    run(["ansible-playbook", f"playbooks/{playbook}.yml", *extra_args], cwd=ANSIBLE_DIR)


@click.group()
def cli() -> None:
    """Homelab automation CLI."""


@cli.command("check-tools")
def check_tools() -> None:
    for tool in ["pass", "gpg", "terraform", "ansible-playbook", "ansible-galaxy", "ssh", "kubectl", "git"]:
        click.echo(f"{tool}: {'ok' if which(tool) else 'missing'}")


@cli.command("ssh", context_settings={"ignore_unknown_options": True, "allow_interspersed_args": False})
@click.argument("name")
@click.argument("remote_args", nargs=-1, type=click.UNPROCESSED)
@click.option("--identity", type=click.Choice(["ryan", "automation"]), default="ryan", show_default=True)
def ssh_host(name: str, remote_args: tuple[str, ...], identity: str) -> None:
    ssh_exec(name, list(remote_args), identity=identity, allocate_tty=not remote_args)


@cli.group()
def secrets() -> None:
    """Manage the repo-local homelab password store."""


@secrets.command("init")
def secrets_init() -> None:
    require_tool("gpg")
    require_tool("pass")
    run([str(SECRETS_INIT_SCRIPT)], cwd=ROOT_DIR, env=env_with_pass())


@secrets.command("render")
def secrets_render() -> None:
    render_secrets()


@secrets.command("list")
def secrets_list() -> None:
    root = PASS_STORE_DIR / PASS_PREFIX
    if not root.exists():
        raise click.ClickException(f"pass subtree not found: {root}")
    for path in sorted(root.rglob("*.gpg")):
        click.echo(str(path.relative_to(PASS_STORE_DIR).with_suffix("")))


@secrets.command("get")
@click.argument("key")
@click.option("--reveal", is_flag=True, help="Print the secret value.")
def secrets_get(key: str, reveal: bool) -> None:
    value = pass_get(key)
    click.echo(value if reveal else f"{pass_path(key)}: present")


@secrets.command("set")
@click.argument("key")
@click.argument("value")
def secrets_set(key: str, value: str) -> None:
    pass_set(key, value)
    click.echo(f"updated {pass_path(key)}")


@cli.group(name="vms")
def vms() -> None:
    """Inspect and access VMs."""


@vms.command("list")
@click.option("--json-output", is_flag=True, help="Print JSON instead of a table.")
def vms_list(json_output: bool) -> None:
    hosts = flatten_hosts()
    groups = host_group_map()
    defs = parse_vm_definitions()
    rows = []
    for name in sorted(hosts):
        if groups.get(name) == "proxmox_hosts":
            continue
        terraform_data = defs.get(name, {})
        rows.append(
            {
                "name": name,
                "group": groups.get(name),
                "ip": hosts[name].get("ansible_host") or terraform_data.get("ip_address"),
                "role": terraform_data.get("role"),
                "vm_id": terraform_data.get("vm_id"),
            }
        )

    if json_output:
        click.echo(json.dumps(rows, indent=2))
        return

    for row in rows:
        click.echo(
            "{name}\t{ip}\t{group}\t{role}\tvmid={vm_id}".format(
                name=row["name"],
                ip=row["ip"] or "?",
                group=row["group"] or "?",
                role=row["role"] or "?",
                vm_id=row["vm_id"] or "?",
            )
        )


@vms.command("get")
@click.argument("name")
def vms_get(name: str) -> None:
    hosts = flatten_hosts()
    groups = host_group_map()
    defs = parse_vm_definitions()
    if name not in hosts and name not in defs:
        raise click.ClickException(f"unknown VM: {name}")
    click.echo(
        json.dumps(
            {
                "name": name,
                "group": groups.get(name),
                "inventory": hosts.get(name, {}),
                "terraform": defs.get(name, {}),
            },
            indent=2,
        )
    )


@vms.command("ssh", context_settings={"ignore_unknown_options": True, "allow_interspersed_args": False})
@click.argument("name")
@click.argument("remote_args", nargs=-1, type=click.UNPROCESSED)
def vms_ssh(name: str, remote_args: tuple[str, ...]) -> None:
    ssh_exec(name, list(remote_args), allocate_tty=not remote_args)


@cli.group(name="k8s")
def k8s() -> None:
    """Inspect and access Kubernetes clusters."""


@k8s.command("list")
def k8s_list() -> None:
    for name, info in cluster_info_map().items():
        click.echo(
            f"{name}\tapi={info['api_domain']} ({info['api_ip']})\tingress={info['ingress_domain']} ({info['ingress_ip']})"
        )


@k8s.command("get")
@click.argument("name")
def k8s_get(name: str) -> None:
    info = cluster_info_map().get(name)
    if not info:
        raise click.ClickException(f"unknown cluster: {name}")
    click.echo(json.dumps(info, indent=2))


@k8s.command("kubeconfig")
@click.argument("name")
@click.option("--sync", "sync_now", is_flag=True, help="Refresh the local kubeconfig from the control plane.")
def k8s_kubeconfig(name: str, sync_now: bool) -> None:
    if name not in cluster_info_map():
        raise click.ClickException(f"unknown cluster: {name}")
    click.echo(str(ensure_local_kubeconfig(name, refresh=sync_now)))


@k8s.command("kubectl", context_settings={"ignore_unknown_options": True, "allow_interspersed_args": False})
@click.argument("name")
@click.argument("kubectl_args", nargs=-1, type=click.UNPROCESSED)
@click.option("--remote", is_flag=True, help="Run kubectl over SSH on the first control-plane node.")
@click.option("--refresh-kubeconfig", is_flag=True, help="Refresh the local kubeconfig before local kubectl.")
def k8s_kubectl(name: str, kubectl_args: tuple[str, ...], remote: bool, refresh_kubeconfig: bool) -> None:
    if name not in cluster_info_map():
        raise click.ClickException(f"unknown cluster: {name}")

    if remote:
        remote_cmd = ["sudo", "kubectl", *kubectl_args]
        ssh_exec(primary_control_plane(name), remote_cmd, allocate_tty=True)
        return

    require_tool("kubectl")
    kubeconfig = ensure_local_kubeconfig(name, refresh=refresh_kubeconfig)
    env = os.environ.copy()
    env["KUBECONFIG"] = str(kubeconfig)
    os.execvpe("kubectl", ["kubectl", *kubectl_args], env)


@cli.group()
def deploy() -> None:
    """Run Terraform and Ansible workflows."""


@deploy.command("init")
def deploy_init() -> None:
    render_secrets()
    terraform_init()
    install_ansible_collections()


@deploy.command("terraform-plan")
def deploy_terraform_plan() -> None:
    render_secrets()
    terraform_init()
    terraform_plan()


@deploy.command("terraform-apply")
@click.option("--auto-approve", is_flag=True, help="Pass -auto-approve to terraform apply.")
def deploy_terraform_apply(auto_approve: bool) -> None:
    render_secrets()
    terraform_init()
    terraform_apply(auto_approve=auto_approve)


@deploy.command("ansible")
@click.argument("playbook", type=click.Choice(["proxmox", "penzance", "cluster", "site"]))
@click.argument("extra_args", nargs=-1, type=click.UNPROCESSED)
def deploy_ansible(playbook: str, extra_args: tuple[str, ...]) -> None:
    render_secrets()
    run_ansible_playbook(playbook, extra_args)


@deploy.command("all")
@click.option("--auto-approve", is_flag=True, help="Pass -auto-approve to terraform apply.")
@click.option("--playbook", type=click.Choice(["proxmox", "penzance", "cluster", "site"]), default="site")
def deploy_all(auto_approve: bool, playbook: str) -> None:
    click.echo("Running secrets render, terraform init/plan/apply, ansible collection install, and ansible playbook")
    render_secrets()
    terraform_init()
    install_ansible_collections()
    terraform_plan()
    terraform_apply(auto_approve=auto_approve)
    run_ansible_playbook(playbook)


@deploy.command("bootstrap")
def deploy_bootstrap() -> None:
    click.echo("Running secrets render, terraform init, ansible collection install, and site playbook")
    render_secrets()
    terraform_init()
    install_ansible_collections()
    run_ansible_playbook("site")


@cli.command("paths")
def paths() -> None:
    data = {
        "root_dir": str(ROOT_DIR),
        "pass_store_dir": str(PASS_STORE_DIR),
        "pass_prefix": PASS_PREFIX,
        "inventory_path": str(INVENTORY_PATH),
        "group_vars_path": str(GROUP_VARS_PATH),
        "terraform_vars_path": str(TFVARS_PATH),
        "ssh_keys_dir": str(SSH_KEYS_DIR),
        "kubeconfig_dir": str(KUBECONFIG_DIR),
    }
    click.echo(json.dumps(data, indent=2))


if __name__ == "__main__":
    cli()
