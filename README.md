# ASN Scanner

一个分布式的 ASN 扫描和代理发现系统。

## 功能特性

- ASN 信息管理和扫描
- IP 段自动扫描
- 代理服务器发现和验证
- 分布式任务处理
- 实时监控和告警
- Web 界面管理

## 系统要求

- Docker 20.10+
- Docker Compose 2.0+
- 至少 4GB RAM
- 2 核 CPU

## 快速开始

1. 克隆项目：
```bash
git clone https://github.com/yourusername/asn-scanner.git
cd asn-scanner
```

2. 配置环境变量：
```bash
cp .env.example .env
# 编辑 .env 文件，设置必要的环境变量
```

3. 启动服务：
```bash
# 构建镜像
docker-compose build

# 启动所有服务
docker-compose up -d

# 初始化数据库
docker-compose exec web-master alembic upgrade head
```

4. 访问服务：
- Web 界面: http://localhost
- Consul UI: http://localhost:8500
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090

## 项目结构

```
asn-scanner/
├── api/                # API接口
├── frontend/          # 前端代码
├── models/            # 数据模型
├── scanner/           # 扫描器核心代码
├── scheduler/         # 任务调度
├── utils/             # 工具函数
├── tests/             # 测试用例
├── alembic/           # 数据库迁移
├── nginx/             # Nginx配置
├── prometheus/        # Prometheus配置
├── docker/            # Docker相关文件
└── logs/              # 日志文件
```

## 开发指南

### 本地开发环境设置

1. 安装依赖：
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
# 或
.\venv\Scripts\activate  # Windows

pip install -r requirements.txt
```

2. 安装前端依赖：
```bash
cd frontend
npm install
```

3. 启动开发服务器：
```bash
# 后端
uvicorn api.main:app --reload

# 前端
npm run dev
```

### 运行测试

```bash
# 运行所有测试
pytest

# 运行特定测试
pytest tests/test_scanner.py -v

# 测试覆盖率报告
pytest --cov=.
```

## 部署指南

### 单节点部署

使用 docker-compose 直接部署：
```bash
docker-compose up -d
```

### 集群部署

1. 修改 docker-compose.yml 添加更多 worker：
```bash
docker-compose up -d --scale web-worker=3
```

2. 配置负载均衡：
```bash
# 编辑 nginx/nginx.conf 添加新节点
```

### 监控配置

1. Prometheus 指标：
- scan_requests_total
- proxy_checks_total
- scan_duration_seconds
- proxy_check_duration_seconds

2. Grafana 仪表板：
- 系统概览
- 扫描任务监控
- 代理状态监控
- 节点状态监控

## 维护指南

### 日常维护

1. 日志查看：
```bash
docker-compose logs -f [service_name]
```

2. 数据库备份：
```bash
docker-compose exec db mysqldump -u user -p asn_scanner > backup.sql
```

3. 更新服务：
```bash
git pull
docker-compose build
docker-compose up -d
```

### 故障处理

1. 服务无法启动：
- 检查日志
- 验证配置
- 确认端口占用

2. 节点通信问题：
- 检查 Consul 服务
- 验证网络连接
- 查看节点状态

## 贡献指南

1. Fork 项目
2. 创建特性分支
3. 提交变更
4. 推送到分支
5. 创建 Pull Request

## 许可证

MIT License