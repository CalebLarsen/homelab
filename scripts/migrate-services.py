import os

def parse_services():
    with open('inventory/group_vars/all/main.yml', 'r') as f:
        lines = f.readlines()

    services = []
    current_service = None
    in_services = False

    for line in lines:
        if line.startswith('services:'):
            in_services = True
            continue
        if not in_services:
            continue
        if line.startswith('  -'):
            if current_service:
                services.append(current_service)
            current_service = [line]
        elif line.startswith('    ') and current_service:
            current_service.append(line)
        elif not line.strip():
            continue
        else:
            if in_services: # Next top level key
                if current_service:
                    services.append(current_service)
                break
    return services

services = parse_services()
for s in services:
    # First line is '  - name: ...'
    name_line = s[0]
    name = name_line.split('name:')[1].split('#')[0].strip()
    target_dir = f'services/{name}'
    os.makedirs(target_dir, exist_ok=True)
    with open(f'{target_dir}/service.yml', 'w') as f:
        # Strip the leading '  -' from the first line and then unindent the rest
        f.write(s[0].replace('  - ', '', 1))
        for line in s[1:]:
            f.write(line.replace('    ', '', 1))

print(f"Migrated {len(services)} services.")
