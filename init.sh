#!/bin/bash

# 创建目录结构
mkdir -p {api,models,scanner,utils,tests,prometheus}

# 创建必要的文件
touch api/__init__.py
touch models/__init__.py
touch scanner/__init__.py
touch utils/__init__.py
touch tests/__init__.py

# 创建 requirements.txt
cat > requirements.txt << 'EOF'
# Web框架
fastapi==0.68.1
uvicorn==0.15.0
python-multipart==0.0.5
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4

# 数据库
sqlalchemy==1.4.23
alembic==1.7.1
pymysql==1.0.2
redis==3.5.3

# 任务队列
celery==5.1.2

# 网络
aiohttp==3.7.4
masscan==0.0.4
python-nmap==0.7.1

# 服务发现
python-consul==1.1.0

# 监控
prometheus-client==0.11.0

# 测试
pytest==6.2.5
pytest-asyncio==0.15.1
pytest-cov==2.12.1
httpx==0.19.0

# 工具
python-dotenv==0.19.0
pydantic==1.8.2
EOF

# 创建 requirements.scanner.txt
cat > requirements.scanner.txt << 'EOF'
# 网络扫描
aiohttp==3.7.4
masscan==0.0.4
python-nmap==0.7.1

# 消息队列
redis==3.5.3

# 工具
python-dotenv==0.19.0
pydantic==1.8.2
EOF

# 创建 scanner/worker.py
cat > scanner/worker.py << 'EOF'
import asyncio
import json
import os
import aiohttp
from scanner.network_scanner import NetworkScanner
from utils.logger import setup_logger

logger = setup_logger("scanner_worker")

class ScannerWorker:
    def __init__(self):
        self.worker_id = os.getenv("WORKER_ID")
        self.master_url = os.getenv("MASTER_URL", "main.curl.im")
        self.scanner = NetworkScanner()
        
    async def report_result(self, result: dict):
        """向主节点报告扫描结果"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"http://{self.master_url}/api/scan/results",
                    json=result
                ) as response:
                    if response.status != 200:
                        logger.error(f"Failed to report result: {await response.text()}")
                    return await response.json()
        except Exception as e:
            logger.error(f"Error reporting result: {str(e)}")
            
    async def get_task(self):
        """从主节点获取任务"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    f"http://{self.master_url}/api/scan/tasks?worker_id={self.worker_id}"
                ) as response:
                    if response.status == 200:
                        return await response.json()
        except Exception as e:
            logger.error(f"Error getting task: {str(e)}")
        return None
        
    async def run(self):
        """运行扫描工作循环"""
        while True:
            try:
                # 获取任务
                task = await self.get_task()
                if not task:
                    await asyncio.sleep(5)
                    continue
                
                # 执行扫描
                if task["type"] == "ip_scan":
                    results = await self.scanner.scan_subnet(task["target"])
                elif task["type"] == "proxy_check":
                    results = await self.scanner.check_proxy(task["target"])
                
                # 报告结果
                await self.report_result({
                    "task_id": task["id"],
                    "worker_id": self.worker_id,
                    "results": results
                })
                
            except Exception as e:
                logger.error(f"Worker error: {str(e)}")
                await asyncio.sleep(5)

if __name__ == "__main__":
    worker = ScannerWorker()
    asyncio.run(worker.run())
EOF

# 创建 scanner/network_scanner.py
cat > scanner/network_scanner.py << 'EOF'
import asyncio
import nmap
import masscan
from utils.logger import setup_logger

logger = setup_logger("network_scanner")

class NetworkScanner:
    def __init__(self):
        self.nmap_scanner = nmap.PortScanner()
        self.mass_scanner = masscan.PortScanner()
        
    async def scan_subnet(self, target: str):
        """扫描IP段"""
        try:
            # 使用masscan快速扫描
            self.mass_scanner.scan(
                target,
                ports="1-65535",
                arguments="--max-rate 1000"
            )
            
            results = []
            for ip in self.mass_scanner.scan_result['scan']:
                ports = [p['port'] for p in self.mass_scanner.scan_result['scan'][ip]['tcp']]
                if ports:
                    # 使用nmap进行详细扫描
                    self.nmap_scanner.scan(ip, arguments=f'-p{",".join(map(str, ports))} -sV')
                    service_info = self.nmap_scanner[ip]['tcp']
                    results.append({
                        'ip': ip,
                        'ports': ports,
                        'services': service_info
                    })
                    
            return results
            
        except Exception as e:
            logger.error(f"Scan error for {target}: {str(e)}")
            return []
            
    async def check_proxy(self, target: dict):
        """检查代理服务器"""
        ip = target['ip']
        port = target['port']
        try:
            # 检查HTTP代理
            http_result = await self._check_http_proxy(ip, port)
            if http_result['is_valid']:
                return http_result
                
            # 检查SOCKS5代理
            socks5_result = await self._check_socks5_proxy(ip, port)
            if socks5_result['is_valid']:
                return socks5_result
                
            return {'is_valid': False, 'type': None}
            
        except Exception as e:
            logger.error(f"Proxy check error for {ip}:{port}: {str(e)}")
            return {'is_valid': False, 'type': None}
            
    async def _check_http_proxy(self, ip: str, port: int):
        """检查HTTP代理"""
        # 实现HTTP代理检查逻辑
        pass
        
    async def _check_socks5_proxy(self, ip: str, port: int):
        """检查SOCKS5代理"""
        # 实现SOCKS5代理检查逻辑
        pass
EOF

# 创建 utils/logger.py
cat > utils/logger.py << 'EOF'
import logging
import os
from logging.handlers import RotatingFileHandler

def setup_logger(name):
    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)

    # 创建日志目录
    os.makedirs('logs', exist_ok=True)

    # 文件处理器
    file_handler = RotatingFileHandler(
        f'logs/{name}.log',
        maxBytes=10*1024*1024,  # 10MB
        backupCount=5
    )
    file_handler.setFormatter(logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    ))
    logger.addHandler(file_handler)

    # 控制台处理器
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(logging.Formatter(
        '%(asctime)s - %(levelname)s - %(message)s'
    ))
    logger.addHandler(console_handler)

    return logger
EOF

# 创建 config.py
cat > config.py << 'EOF'
import os
from dotenv import load_dotenv

load_dotenv()

# 基础配置
DEBUG = os.getenv('DEBUG', 'false').lower() == 'true'
SECRET_KEY = os.getenv('SECRET_KEY')

# 数据库配置
DATABASE_URL = os.getenv('DATABASE_URL')

# Redis配置
REDIS_URL = os.getenv('REDIS_URL')

# 节点配置
NODE_ROLE = os.getenv('NODE_ROLE', 'worker')
WORKER_ID = os.getenv('WORKER_ID', '1')
MASTER_URL = os.getenv('MASTER_URL', 'main.curl.im')

# 扫描配置
SCAN_BATCH_SIZE = int(os.getenv('SCAN_BATCH_SIZE', '100'))
PROXY_CHECK_TIMEOUT = int(os.getenv('PROXY_CHECK_TIMEOUT', '10'))
EOF

# 创建 prometheus/prometheus.yml
cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'asn-scanner'
    consul_sd_configs:
      - server: 'consul:8500'
        services: ['asn-master', 'asn-worker']
    
    relabel_configs:
      - source_labels: [__meta_consul_service]
        target_label: service
      - source_labels: [__meta_consul_node]
        target_label: node
      - source_labels: [__meta_consul_tags]
        target_label: role

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
EOF

chmod +x deploy.sh

echo "初始化完成！现在可以运行 ./deploy.sh 来部署系统。"