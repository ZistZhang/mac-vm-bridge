# 架构说明

```
[宿主 macOS]
    |
    +-- Wi‑Fi (en0) 桥接 192.168.200.0/24
    |       |
    |       +-- QEMU 来宾（业务口 .131: 业务端口; 管理口 NAT: 127.0.0.1:2222 → 22）
    |       |
    |       +-- Parallels Windows（业务口 .2）
    |
    +-- NAT 回环（仅管理口）
```

- 业务网段不配置默认网关，避免影响默认上网
- Windows 通过 Parallels Tools 执行网卡配置
- QEMU 使用 TCG（Apple Silicon 跑 x86_64）
