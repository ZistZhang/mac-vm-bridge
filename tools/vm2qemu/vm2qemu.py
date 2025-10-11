#!/usr/bin/env python3
import argparse, subprocess, sys, os, re, textwrap, tarfile, tempfile, xml.etree.ElementTree as ET

BANNER = "Mac VM Bridge - vm2qemu tool (prototype)"

def sh(cmd, check=True):
    print("$", " ".join(cmd))
    r = subprocess.run(cmd)
    if check and r.returncode != 0:
        sys.exit(r.returncode)

# --- Detect helpers ---

def read_vmx(vmx_path:str):
    res = {}
    with open(vmx_path,'r',errors='ignore') as f:
        for line in f:
            m = re.match(r'((?:ide|scsi)\d+:\d+\.fileName)\s*=\s*"(.+?)"', line.strip())
            if m:
                res[m.group(1)] = m.group(2)
    return res

def detect_from_vmx(vmx):
    vmx = os.path.abspath(vmx)
    if not os.path.exists(vmx):
        print('vmx not found:', vmx, file=sys.stderr); sys.exit(2)
    mapping = read_vmx(vmx)
    if not mapping:
        print('no disk entries in vmx', file=sys.stderr); sys.exit(2)
    order = ['scsi0:0.fileName'] + [k for k in mapping if k.startswith('scsi') and k!='scsi0:0.fileName'] + [k for k in mapping if k.startswith('ide')]
    chosen = None
    for k in order:
        if k in mapping:
            chosen = mapping[k]; break
    if not chosen:
        chosen = next(iter(mapping.values()))
    disk = os.path.join(os.path.dirname(vmx), chosen)
    return disk

def detect_from_ovf(ovf):
    ovf = os.path.abspath(ovf)
    if not os.path.exists(ovf):
        print('ovf not found:', ovf, file=sys.stderr); sys.exit(2)
    tree = ET.parse(ovf)
    root = tree.getroot()
    ns = {'ovf':'http://schemas.dmtf.org/ovf/envelope/1'}
    href = None
    for f in root.findall('.//ovf:References/ovf:File', ns):
        href = f.attrib.get('{http://schemas.dmtf.org/ovf/envelope/1}href') or f.attrib.get('ovf:href') or f.attrib.get('href')
        if href and href.lower().endswith('.vmdk'):
            break
    if not href:
        print('no vmdk href in ovf', file=sys.stderr); sys.exit(2)
    return os.path.join(os.path.dirname(ovf), href)

# --- Commands ---

def cmd_detect(args):
    p = args.path
    if p.lower().endswith('.vmx'):
        print(detect_from_vmx(p))
    elif p.lower().endswith('.ovf'):
        print(detect_from_ovf(p))
    elif p.lower().endswith('.ova'):
        with tempfile.TemporaryDirectory() as td:
            with tarfile.open(p, 'r:*') as t:
                t.extractall(td)
            # find ovf then vmdk
            ovfs = [os.path.join(td,f) for f in os.listdir(td) if f.lower().endswith('.ovf')]
            if not ovfs:
                print('no ovf in ova', file=sys.stderr); sys.exit(2)
            print(detect_from_ovf(ovfs[0]))
    elif p.lower().endswith('.vmdk'):
        print(os.path.abspath(p))
    else:
        print('unsupported input; use .ova/.ovf/.vmx/.vmdk', file=sys.stderr); sys.exit(2)

def cmd_convert(args):
    src = os.path.abspath(args.src)
    outdir = os.path.abspath(args.out)
    os.makedirs(outdir, exist_ok=True)
    if not os.path.exists(src):
        print('src not found:', src, file=sys.stderr); sys.exit(2)
    if src.lower().endswith('.vmx'):
        src = detect_from_vmx(src)
    elif src.lower().endswith('.ovf'):
        src = detect_from_ovf(src)
    elif src.lower().endswith('.ova'):
        with tempfile.TemporaryDirectory() as td:
            with tarfile.open(src, 'r:*') as t:
                t.extractall(td)
            ovfs = [os.path.join(td,f) for f in os.listdir(td) if f.lower().endswith('.ovf')]
            if not ovfs:
                print('no ovf in ova', file=sys.stderr); sys.exit(2)
            src = detect_from_ovf(ovfs[0])
    name = args.name or 'disk.qcow2'
    qcow2 = os.path.join(outdir, name)
    sh(["qemu-img","convert","-p","-O","qcow2", src, qcow2])
    print('qcow2:', qcow2)

def cmd_run(args):
    disk = os.path.abspath(args.disk)
    if not os.path.exists(disk):
        print('disk not found:', disk, file=sys.stderr); sys.exit(2)
    qemu = args.qemu or 'qemu-system-x86_64'
    br = args.bridge
    port = str(args.nat_port)
    env = os.environ.copy()
    env['OBJC_DISABLE_INITIALIZE_FORK_SAFETY'] = 'YES'
    cmd = [
        'sudo','--preserve-env=OBJC_DISABLE_INITIALIZE_FORK_SAFETY', qemu,
        '-accel','tcg,thread=multi','-cpu','max','-smp',str(args.cpus),'-m',args.mem,
        '-drive',f'file={disk},format=qcow2,if=virtio,cache=writeback',
        '-netdev',f'user,id=mgmt,hostfwd=tcp:127.0.0.1:{port}-:22',
        '-device','virtio-net-pci,netdev=mgmt,mac=52:54:00:22:33:45',
        '-netdev',f'vmnet-bridged,id=biz,ifname={br}',
        '-device','virtio-net-pci,netdev=biz,mac=52:54:00:22:33:44',
        '-vga','virtio','-display','default,show-cursor=on',
        '-daemonize','-pidfile','vm.pid','-qmp','unix:qmp.sock,server,nowait',
        '-D','qemu.log','-msg','timestamp=on'
    ]
    print('$', ' '.join(cmd))
    subprocess.run(cmd, env=env, check=True)
    print('Started. SSH 127.0.0.1:%s; QMP qmp.sock' % port)


def main():
    ap = argparse.ArgumentParser(description=BANNER)
    sub = ap.add_subparsers(dest='cmd', required=True)

    p = sub.add_parser('detect'); p.add_argument('--path', required=True); p.set_defaults(func=lambda a: print(cmd_detect(a) or ''))
    p = sub.add_parser('convert'); p.add_argument('--src', required=True); p.add_argument('--out', required=True); p.add_argument('--name'); p.set_defaults(func=cmd_convert)
    p = sub.add_parser('run'); p.add_argument('--disk', required=True); p.add_argument('--bridge', default='en0'); p.add_argument('--nat-port', type=int, default=2222); p.add_argument('--mem', default='4G'); p.add_argument('--cpus', type=int, default=4); p.add_argument('--qemu'); p.set_defaults(func=cmd_run)

    args = ap.parse_args()
    if hasattr(args, 'func'):
        args.func(args)

if __name__ == '__main__':
    main()
