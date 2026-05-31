import paramiko, time, sys

host = '<your-linux-server>'
user = 'user'
password = '123456'
pubkey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDxr8YUAroLRa9DuqR+uxumqHh05O33OvoBmFVVWrTAl oferhuertolw503@gmail.com'

for attempt in range(5):
    try:
        print(f'Attempt {attempt+1}...')
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(host, username=user, password=password, look_for_keys=False, allow_agent=False, timeout=15)

        ssh.exec_command('mkdir -p ~/.ssh && chmod 700 ~/.ssh')
        cmd = f'grep -q "{pubkey}" ~/.ssh/authorized_keys 2>/dev/null || echo "{pubkey}" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
        stdin, stdout, stderr = ssh.exec_command(cmd)
        print('stdout:', stdout.read().decode())
        print('stderr:', stderr.read().decode())

        stdin, stdout, stderr = ssh.exec_command('echo KEY_OK && hostname && pwd')
        print(stdout.read().decode().strip())
        ssh.close()
        print('SUCCESS')
        sys.exit(0)
    except Exception as e:
        print(f'  Failed: {e}')
        if attempt < 4:
            print('  Waiting 5s...')
            time.sleep(5)

print('FAILED after 5 attempts')
sys.exit(1)
