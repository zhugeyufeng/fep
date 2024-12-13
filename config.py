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