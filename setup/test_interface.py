import streamlit as st
import subprocess
import re
import os
import json
from pathlib import Path
import time

# Page configuration
st.set_page_config(
    page_title="Attack Container Deployer",
    page_icon="🐳",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
<style>
    .stButton button {
        width: 100%;
    }
    .success-box {
        padding: 1rem;
        border-radius: 0.5rem;
        background-color: #d4edda;
        color: #155724;
        margin: 1rem 0;
    }
    .error-box {
        padding: 1rem;
        border-radius: 0.5rem;
        background-color: #f8d7da;
        color: #721c24;
        margin: 1rem 0;
    }
    .info-box {
        padding: 1rem;
        border-radius: 0.5rem;
        background-color: #d1ecf1;
        color: #0c5460;
        margin: 1rem 0;
    }
</style>
""", unsafe_allow_html=True)

# Attack types with their configurations
ATTACK_TYPES = {
    "ddos": {
        "name": "DDoS Attack",
        "icon": "💣",
        "description": "Distributed Denial of Service attack container",
        "default_name_prefix": "ddos"
    },
    "sql_injection": {
        "name": "SQL Injection",
        "icon": "🗄️",
        "description": "SQL injection attack container",
        "default_name_prefix": "sql"
    },
    "ping_flood": {
        "name": "Ping Flood",
        "icon": "📡",
        "description": "ICMP ping flood attack container",
        "default_name_prefix": "ping"
    },
    "dns_tunneling": {
        "name": "DNS Tunneling",
        "icon": "🔒",
        "description": "DNS tunneling attack container",
        "default_name_prefix": "dns"
    },
    "brute_force_ssh": {
        "name": "SSH Brute Force",
        "icon": "🔑",
        "description": "SSH brute force attack container",
        "default_name_prefix": "brute"
    }
}

# Function to validate MAC address
def validate_mac(mac):
    pattern = re.compile(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$')
    return bool(pattern.match(mac))

# Function to validate IP address
def validate_ip(ip):
    pattern = re.compile(r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')
    return bool(pattern.match(ip))

# Function to deploy container
def deploy_container(
    attack_type,
    container_name,
    mac_address,
    use_dhcp,
    static_ip,
    bridge_name,
    script_dir
):
    try:
        # Build the command
        cmd = [os.path.join(script_dir, "deploy_container_attack.sh")]

        # Add attack type option
        if attack_type == "ddos":
            cmd.append("-d")
        elif attack_type == "sql_injection":
            cmd.append("-s")
        elif attack_type == "ping_flood":
            cmd.append("-p")
        elif attack_type == "dns_tunneling":
            cmd.append("-dt")
        elif attack_type == "brute_force_ssh":
            cmd.append("-br")

        # Add container name
        cmd.extend(["--name", container_name])

        # Add MAC address
        if mac_address:
            cmd.extend(["--mac", mac_address])

        # Add network configuration
        if not use_dhcp:
            cmd.append("--no-dhcp")
            if static_ip:
                cmd.extend(["--ip", static_ip])

        # Add bridge name
        cmd.extend(["--bridge", bridge_name])

        # Execute command
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=script_dir
        )

        if result.returncode == 0:
            return True, result.stdout + result.stderr
        else:
            return False, result.stderr

    except Exception as e:
        return False, str(e)

# Function to list running containers
def list_containers():
    try:
        result = subprocess.run(
            ["docker", "ps", "--format", "json"],
            capture_output=True,
            text=True
        )
        if result.returncode == 0 and result.stdout:
            containers = []
            for line in result.stdout.strip().split('\n'):
                try:
                    containers.append(json.loads(line))
                except:
                    pass
            return containers
        return []
    except:
        return []

# Function to stop container
def stop_container(container_name):
    try:
        result = subprocess.run(
            ["docker", "stop", container_name],
            capture_output=True,
            text=True
        )
        return result.returncode == 0, result.stdout + result.stderr
    except Exception as e:
        return False, str(e)

# Function to remove container
def remove_container(container_name):
    try:
        result = subprocess.run(
            ["docker", "rm", "-f", container_name],
            capture_output=True,
            text=True
        )
        return result.returncode == 0, result.stdout + result.stderr
    except Exception as e:
        return False, str(e)

# Function to get container logs
def get_container_logs(container_name, lines=50):
    try:
        result = subprocess.run(
            ["docker", "logs", "--tail", str(lines), container_name],
            capture_output=True,
            text=True
        )
        return result.stdout + result.stderr
    except Exception as e:
        return str(e)

# Main application
def main():
    st.title("🐳 Attack Container Deployer")
    st.markdown("Web interface for deploying attack containers")

    # Sidebar
    with st.sidebar:
        st.header("⚙️ Configuration")

        # Script directory
        script_dir = st.text_input(
            "Script Directory",
            value=os.getcwd(),
            help="Directory containing deploy_container_attack.sh and mac_manager.sh"
        )

        if not os.path.exists(os.path.join(script_dir, "deploy_container_attack.sh")):
            st.error("⚠️ deploy_container_attack.sh not found in specified directory")

        st.divider()

        # Bridge configuration
        bridge_name = st.text_input(
            "Bridge Name",
            value="bridge-tap",
            help="Name of the bridge to attach containers to"
        )

        st.divider()

        # Display active containers
        st.header("📦 Active Containers")
        containers = list_containers()

        if containers:
            for container in containers:
                with st.expander(f"📦 {container.get('Names', 'Unknown')}"):
                    st.text(f"Image: {container.get('Image', 'N/A')}")
                    st.text(f"Status: {container.get('Status', 'N/A')}")
                    st.text(f"Created: {container.get('CreatedAt', 'N/A')}")

                    col1, col2 = st.columns(2)
                    with col1:
                        if st.button(f"📋 Logs", key=f"logs_{container.get('Names')}"):
                            logs = get_container_logs(container.get('Names'))
                            st.code(logs, language="bash")
                    with col2:
                        if st.button(f"🛑 Stop", key=f"stop_{container.get('Names')}"):
                            success, msg = stop_container(container.get('Names'))
                            if success:
                                st.success(f"Container {container.get('Names')} stopped")
                                st.rerun()
                            else:
                                st.error(f"Failed to stop: {msg}")

                    if st.button(f"🗑️ Remove", key=f"remove_{container.get('Names')}"):
                        success, msg = remove_container(container.get('Names'))
                        if success:
                            st.success(f"Container {container.get('Names')} removed")
                            st.rerun()
                        else:
                            st.error(f"Failed to remove: {msg}")
        else:
            st.info("No active containers")

    # Main content - Two columns
    col1, col2 = st.columns([1, 1])

    with col1:
        st.header("🎯 Attack Configuration")

        # Select attack type
        attack_type = st.selectbox(
            "Attack Type",
            options=list(ATTACK_TYPES.keys()),
            format_func=lambda x: f"{ATTACK_TYPES[x]['icon']} {ATTACK_TYPES[x]['name']}"
        )

        # Display attack description
        st.info(ATTACK_TYPES[attack_type]["description"])

        # Container name
        default_name = f"{ATTACK_TYPES[attack_type]['default_name_prefix']}_{int(time.time())}"
        container_name = st.text_input(
            "Container Name",
            value=default_name,
            help="Unique name for the container"
        )

        # MAC address configuration
        st.subheader("📍 MAC Address Configuration")
        mac_address = st.text_input(
            "MAC Address",
            placeholder="XX:XX:XX:XX:XX:XX",
            help="Format: 12:34:56:78:90:AB",
            key="mac_input"
        )

        if mac_address and not validate_mac(mac_address):
            st.error("Invalid MAC address format. Expected format: XX:XX:XX:XX:XX:XX")

        # Network configuration
        st.subheader("🌐 Network Configuration")
        use_dhcp = st.checkbox("Use DHCP", value=True)

        static_ip = None
        if not use_dhcp:
            static_ip = st.text_input(
                "Static IP Address",
                placeholder="192.168.1.100",
                help="Assign static IP to container"
            )
            if static_ip and not validate_ip(static_ip):
                st.error("Invalid IP address format")

    with col2:
        st.header("🚀 Deployment")

        # Deployment button
        deploy_button = st.button(
            "Deploy Container",
            type="primary",
            use_container_width=True
        )

        if deploy_button:
            # Validation
            errors = []

            if not os.path.exists(os.path.join(script_dir, "deploy_container_attack.sh")):
                errors.append("deploy_container_attack.sh not found")

            if not container_name:
                errors.append("Container name is required")

            if not mac_address:
                errors.append("MAC address is required")
            elif not validate_mac(mac_address):
                errors.append("Invalid MAC address format")

            if not use_dhcp and static_ip and not validate_ip(static_ip):
                errors.append("Invalid static IP address")

            if errors:
                for error in errors:
                    st.error(f"❌ {error}")
            else:
                with st.spinner("Deploying container..."):
                    success, output = deploy_container(
                        attack_type,
                        container_name,
                        mac_address,
                        use_dhcp,
                        static_ip,
                        bridge_name,
                        script_dir
                    )

                    if success:
                        st.success(f"✅ Container '{container_name}' deployed successfully!")
                        st.markdown(f"""
                        <div class="success-box">
                            <strong>Container Information:</strong><br>
                            • Name: {container_name}<br>
                            • Type: {ATTACK_TYPES[attack_type]['name']}<br>
                            • MAC Address: {mac_address}<br>
                            • Bridge: {bridge_name}
                        </div>
                        """, unsafe_allow_html=True)

                        # Show deployment output
                        with st.expander("Deployment Details"):
                            st.code(output, language="bash")

                        # Command shortcuts
                        st.markdown("### 📝 Useful Commands")
                        st.code(f"""
# View logs
docker logs {container_name}

# Execute bash in container
docker exec -it {container_name} /bin/bash

# Stop container
docker stop {container_name}

# Remove container
docker rm -f {container_name}
                        """, language="bash")
                    else:
                        st.error("❌ Deployment failed!")
                        st.markdown(f"""
                        <div class="error-box">
                            <strong>Error Details:</strong><br>
                            <pre>{output}</pre>
                        </div>
                        """, unsafe_allow_html=True)

        st.divider()

        # Quick commands section
        st.header("🔧 Quick Commands")

        col_cmd1, col_cmd2 = st.columns(2)
        with col_cmd1:
            if st.button("📋 List Containers", use_container_width=True):
                containers = list_containers()
                if containers:
                    st.json(containers)
                else:
                    st.info("No containers running")

        with col_cmd2:
            if st.button("🔍 Check Docker Status", use_container_width=True):
                try:
                    result = subprocess.run(["docker", "ps"], capture_output=True, text=True)
                    st.code(result.stdout, language="bash")
                except Exception as e:
                    st.error(f"Error: {e}")

if __name__ == "__main__":
    main()
