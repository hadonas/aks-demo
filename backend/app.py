from flask import Flask, request, jsonify, session
from flask_cors import CORS
import redis
import mysql.connector
import json
from datetime import datetime
import os
from kafka import KafkaProducer, KafkaConsumer
from functools import wraps
from werkzeug.security import generate_password_hash, check_password_hash
from threading import Thread
import threading
import logging
import sys
import traceback

# OpenTelemetry imports
from opentelemetry import trace, metrics
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry._logs import set_logger_provider
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.mysql import MySQLInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.instrumentation.urllib3 import URLLib3Instrumentor
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

# Prometheus 메트릭 정의
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration', ['method', 'endpoint'])
ACTIVE_USERS = Gauge('active_users_total', 'Total active users')
DB_CONNECTIONS = Gauge('database_connections_active', 'Active database connections')
REDIS_CONNECTIONS = Gauge('redis_connections_active', 'Active Redis connections')

# 자동계측만 사용 (수동 메트릭 제거)

# OpenTelemetry 설정
def setup_opentelemetry():
    # 리소스 설정 (OpenTelemetry 표준 속성)
    resource = Resource.create({
        "service.name": "aks-demo-backend",
        "service.version": "1.0.0",
        "deployment.environment": os.getenv("ENVIRONMENT", "production"),
        "service.instance.id": os.getenv("HOSTNAME", "backend-1"),
        "service.namespace": "aks-demo",
        "container.name": "backend",
        "telemetry.sdk.name": "opentelemetry",
        "telemetry.sdk.language": "python"
    })
    
    
    # TracerProvider 설정
    tracer_provider = TracerProvider(resource=resource)
    trace.set_tracer_provider(tracer_provider)
    tracer = trace.get_tracer(__name__)
    
    
    
    # OTLP Exporter 설정 (외부 Collector 사용) - HTTP 사용
    otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://collector.lgtm.20.249.154.255.nip.io")
    
    # 디버깅 로그

    print(f"🌍 Environment: {os.getenv('ENVIRONMENT', 'production')}")
    
    # Collector 연결 테스트
    import requests
    try:
        health_url = f"{otlp_endpoint}/health"
        response = requests.get(health_url, timeout=5)

    except Exception as e:
        pass
    
    # Trace Exporter 설정 (기본 헤더 사용)
    otlp_exporter = OTLPSpanExporter(
        endpoint=f"{otlp_endpoint}/v1/traces",
        timeout=30,
    )

    
    # Span Processor 설정 (자동계측 최적화)
    span_processor = BatchSpanProcessor(
        otlp_exporter,
        max_queue_size=2048,        # 더 큰 큐 크기
        max_export_batch_size=512,  # 더 큰 배치 크기  
        export_timeout_millis=30000,
        schedule_delay_millis=5000  # 5초마다 배치 전송
    )
    tracer_provider.add_span_processor(span_processor)

    
    # Metrics Exporter 설정 (기본 헤더 사용)
    metric_exporter = OTLPMetricExporter(
        endpoint=f"{otlp_endpoint}/v1/metrics",
        timeout=30,
    )

    
    # Metric Reader 설정 (자동계측 최적화)
    metric_reader = PeriodicExportingMetricReader(
        exporter=metric_exporter,
        export_interval_millis=10000,  # 10초마다 메트릭 전송 (자동계측에 적합)
        export_timeout_millis=30000    # 타임아웃 30초
    )

    
    meter_provider = MeterProvider(
        resource=resource,
        metric_readers=[metric_reader]
    )
    metrics.set_meter_provider(meter_provider)

    
    # LoggerProvider 설정 (자동계측용)
    logger_provider = LoggerProvider(resource=resource)
    
    # Log Exporter 설정 (기본 헤더 사용)
    log_exporter = OTLPLogExporter(
        endpoint=f"{otlp_endpoint}/v1/logs",
        timeout=30,
    )

    
    # Log Processor 설정 (자동계측 최적화)
    log_processor = BatchLogRecordProcessor(
        log_exporter,
        max_queue_size=2048,        # 더 큰 큐 크기
        max_export_batch_size=512,  # 더 큰 배치 크기
        export_timeout_millis=30000,
        schedule_delay_millis=5000  # 5초마다 배치 전송
    )
    logger_provider.add_log_record_processor(log_processor)
    set_logger_provider(logger_provider)
    
    # 자동 계측 설정 (Flask 제외 - 앱 생성 후에 별도로 설정)
    # 데이터베이스 및 네트워크 자동계측
    RequestsInstrumentor().instrument()
    MySQLInstrumentor().instrument()
    RedisInstrumentor().instrument()
    URLLib3Instrumentor().instrument()
    
    # LoggingInstrumentor 설정 (자동계측으로 로그 전송)
    LoggingInstrumentor().instrument(
        set_logging_format=True,
        logging_format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        log_level=logging.INFO
    )
    
    # Python 표준 로거에 OpenTelemetry handler 추가
    otel_handler = LoggingHandler(
        level=logging.INFO,
        logger_provider=logger_provider
    )
    
    # Root logger에 OpenTelemetry handler 추가
    root_logger = logging.getLogger()
    root_logger.addHandler(otel_handler)
    
    # 앱 로거에도 추가
    app_logger = logging.getLogger(__name__)
    app_logger.addHandler(otel_handler)
    app_logger.setLevel(logging.INFO)
    


app = Flask(__name__)
CORS(app, supports_credentials=True)  # 세션을 위한 credentials 지원
app.secret_key = os.getenv('FLASK_SECRET_KEY', 'your-secret-key-here')  # 세션을 위한 시크릿 키

# 자동계측 사용으로 tracer 전역 변수 제거

# 자동계측 로그 테스트
logging.info("AKS Demo Backend application started - Auto-instrumentation enabled")

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# 환경변수 디버깅 출력
logger.info("=== 환경변수 확인 ===")
logger.info(f"MARIADB_HOST: {os.getenv('MARIADB_HOST', 'NOT_SET')}")
logger.info(f"MARIADB_USER: {os.getenv('MARIADB_USER', 'NOT_SET')}")
logger.info(f"MARIADB_PASSWORD: {'****' if os.getenv('MARIADB_PASSWORD') else 'NOT_SET'}")
logger.info(f"REDIS_HOST: {os.getenv('REDIS_HOST', 'NOT_SET')}")
logger.info(f"KAFKA_SERVERS: {os.getenv('KAFKA_SERVERS', 'NOT_SET')}")
logger.info(f"OTEL_EXPORTER_OTLP_ENDPOINT: {os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'NOT_SET')}")
logger.info(f"OTEL_EXPORTER_OTLP_PROTOCOL: {os.getenv('OTEL_EXPORTER_OTLP_PROTOCOL', 'NOT_SET')}")
logger.info("===================")

# OpenTelemetry Collector 연결 테스트
def test_collector_connection():
    """Collector 연결 상태를 테스트하고 실제 데이터를 전송해보는 함수"""
    import requests
    import time
    
    otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://collector.lgtm.20.249.154.255.nip.io")
    

    
    # 1. 기본 HTTP 연결 테스트
    try:
        health_url = f"{otlp_endpoint}/health"
        response = requests.get(health_url, timeout=10)
    except Exception as e:
        pass
    
    # 자동계측을 사용하므로 수동 span 생성 제거

    
    # 3. 강제 flush 시도
    try:
        from opentelemetry.sdk.trace import TracerProvider
        tracer_provider = trace.get_tracer_provider()
        if hasattr(tracer_provider, 'force_flush'):
            tracer_provider.force_flush(timeout_millis=10000)  # 10초로 늘림
    except Exception as e:
        pass
    
    # 4. Metrics provider flush 시도
    try:
        meter_provider = metrics.get_meter_provider()
        if hasattr(meter_provider, 'force_flush'):
            meter_provider.force_flush(timeout_millis=10000)
    except Exception as e:
        pass

# Flask 앱 시작 후 연결 테스트 실행
def run_startup_tests():
    """앱 시작 후 실행할 테스트들"""

    test_collector_connection()
    
    # 로그 전송 테스트
    try:
        logger.info("OpenTelemetry log transmission test - INFO level")
        logger.warning("OpenTelemetry log transmission test - WARNING level")
        logger.error("OpenTelemetry log transmission test - ERROR level (for testing)")
        logger.debug("OpenTelemetry log transmission test - DEBUG level")
        
        # 구조화된 로그 테스트
        logger.info("Structured log test", extra={
            "user_id": "test_user",
            "action": "startup_test",
            "environment": os.getenv("ENVIRONMENT", "development"),
            "service": "aks-demo-backend"
        })
        

    except Exception as e:
        logger.error(f"Log transmission test failed: {str(e)}")
    
    # 자동계측 사용으로 수동 메트릭 제거
    logger.info("Auto-instrumentation is collecting metrics")

# 지연된 OpenTelemetry 초기화 함수
def initialize_opentelemetry():
    """모든 설정이 완료된 후 OpenTelemetry를 초기화"""
    try:
        setup_opentelemetry()
        # Flask 앱에 대한 instrumentation 적용 (앱과 모든 설정 완료 후)
        FlaskInstrumentor().instrument_app(app)
        
        # 초기화 후 테스트 실행
        run_startup_tests()
        
    except Exception as e:
        pass

# 시스템 상태 모니터링 함수
def log_system_stats():
    """시스템 상태를 주기적으로 로그에 기록하고 메트릭 전송"""
    try:
        # 스레드 수
        thread_count = threading.active_count()
        logger.info(f"Thread count: {thread_count}")
        
        # 자동계측 사용으로 수동 메트릭 제거
        
        # 프로세스 ID
        logger.info(f"Process PID: {os.getpid()}")
        
        # Redis 연결 상태 체크
        try:
            redis_client = get_redis_connection()
            redis_info = redis_client.info()
            connected_clients = redis_info.get('connected_clients', 0)
            used_memory = redis_info.get('used_memory', 0)
            
            logger.info(f"Redis status - Connected clients: {connected_clients}")
            logger.info(f"Redis status - Used memory: {redis_info.get('used_memory_human', 'N/A')}")
            
            # 자동계측 사용으로 Redis 수동 메트릭 제거
                
            redis_client.close()
        except Exception as e:
            logger.warning(f"Redis status check failed: {str(e)}")
        
        # 환경 정보
        logger.info(f"Environment: {os.getenv('ENVIRONMENT', 'development')}")
        logger.info(f"OpenTelemetry endpoint: {os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'NOT_SET')}")
            
    except Exception as e:
        logger.error(f"시스템 상태 모니터링 오류: {str(e)}")

# # 주기적 시스템 상태 로깅 (30초마다)
# def schedule_system_monitoring():
#     """주기적으로 시스템 상태를 모니터링"""
#     log_system_stats()
#     threading.Timer(30.0, schedule_system_monitoring).start()  # 30초마다 실행

# 앱 시작 후 지연된 OpenTelemetry 초기화 실행 (백그라운드 스레드에서)
threading.Timer(5.0, initialize_opentelemetry).start()

# 시스템 모니터링 시작 (15초 후)
# threading.Timer(15.0, schedule_system_monitoring).start()

# # 스레드 풀 생성
# thread_pool = ThreadPoolExecutor(max_workers=5)

# MariaDB 연결 함수
def get_db_connection():
    start_time = datetime.now()
    try:
        logger.info("=== MariaDB 연결 시도 ===")
        host = os.getenv('MARIADB_HOST', 'my-mariadb')
        user = os.getenv('MARIADB_USER', 'testuser')
        password = os.getenv('MARIADB_PASSWORD')
        database = "testdb"
        
        logger.info(f"연결 정보: host={host}, user={user}, database={database}")
        logger.debug(f"연결 시작 시간: {start_time}")
        
        connection = mysql.connector.connect(
            host=host,
            user=user,
            password=password,
            port=3306,
            database=database,
            connect_timeout=30
        )
        
        connection_time = (datetime.now() - start_time).total_seconds()
        logger.info(f"MariaDB 연결 성공! (소요시간: {connection_time:.3f}초)")
        logger.debug(f"연결 ID: {connection.connection_id if hasattr(connection, 'connection_id') else 'N/A'}")
        
        return connection
    except Exception as e:
        connection_time = (datetime.now() - start_time).total_seconds()
        logger.error(f"MariaDB 연결 실패 (소요시간: {connection_time:.3f}초): {str(e)}")
        logger.error(f"연결 시도한 정보: host={host}, user={user}, database={database}")
        logger.error(f"에러 타입: {type(e).__name__}")
        raise e

# Redis 연결 함수 (읽기/쓰기용)
def get_redis_connection():
    start_time = datetime.now()
    try:
        host = os.getenv('REDIS_HOST', 'redis-master.sungho.svc.cluster.local')
        logger.debug(f"Redis 마스터 연결 시도: {host}:6379")
        
        redis_client = redis.Redis(
            host=host,
            port=6379,
            username='default',  # Redis 기본 사용자명
            password=os.getenv('REDIS_PASSWORD'),
            decode_responses=True,
            db=0
        )
        
        # 연결 테스트
        redis_client.ping()
        connection_time = (datetime.now() - start_time).total_seconds()
        logger.debug(f"Redis 마스터 연결 성공! (소요시간: {connection_time:.3f}초)")
        
        return redis_client
    except Exception as e:
        connection_time = (datetime.now() - start_time).total_seconds()
        logger.error(f"Redis 마스터 연결 실패 (소요시간: {connection_time:.3f}초): {str(e)}")
        raise e

# Redis 읽기 전용 연결 함수
def get_redis_readonly_connection():
    return redis.Redis(
        host=os.getenv('REDIS_REPLICA_HOST', 'redis-replicas.sungho.svc.cluster.local'),
        port=6379,
        username='default',  # Redis 기본 사용자명
        password=os.getenv('REDIS_PASSWORD'),
        decode_responses=True,
        db=0
    )

# Kafka Producer 설정
def get_kafka_producer():
    start_time = datetime.now()
    try:
        servers = os.getenv('KAFKA_SERVERS', 'my-kafka:9092')
        username = os.getenv('KAFKA_USERNAME', 'user1')
        logger.debug(f"Kafka Producer 연결 시도: {servers}, username: {username}")
        
        producer = KafkaProducer(
            bootstrap_servers=servers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            security_protocol='SASL_PLAINTEXT',
            sasl_mechanism='PLAIN',
            sasl_plain_username=username,
            sasl_plain_password=os.getenv('KAFKA_PASSWORD', '')
        )
        
        connection_time = (datetime.now() - start_time).total_seconds()
        logger.debug(f"Kafka Producer 생성 성공! (소요시간: {connection_time:.3f}초)")
        
        return producer
    except Exception as e:
        connection_time = (datetime.now() - start_time).total_seconds()
        logger.error(f"Kafka Producer 생성 실패 (소요시간: {connection_time:.3f}초): {str(e)}")
        raise e

# 로깅 함수
def log_to_redis(action, details):
    start_time = datetime.now()
    try:
        logger.debug(f"Redis 로그 저장 시작: action={action}")
        redis_client = get_redis_connection()
        
        log_entry = {
            'timestamp': datetime.now().isoformat(),
            'action': action,
            'details': details,
            'source': 'aks-demo-backend',
            'pid': os.getpid()
        }
        
        # 로그 저장
        redis_client.lpush('api_logs', json.dumps(log_entry))
        redis_client.ltrim('api_logs', 0, 99)  # 최근 100개 로그만 유지
        
        # 로그 통계 업데이트
        daily_key = f"daily_logs:{datetime.now().strftime('%Y-%m-%d')}"
        redis_client.incr(daily_key)
        redis_client.expire(daily_key, 86400 * 7)  # 7일 보관
        
        redis_client.close()
        
        log_time = (datetime.now() - start_time).total_seconds()
        logger.debug(f"Redis 로그 저장 완료 (소요시간: {log_time:.3f}초)")
        
    except Exception as e:
        log_time = (datetime.now() - start_time).total_seconds()
        logger.error(f"Redis 로그 저장 실패 (소요시간: {log_time:.3f}초): {str(e)}")
        print(f"Redis logging error: {str(e)}")

# API 통계 로깅을 비동기로 처리하는 함수
def async_log_api_stats(endpoint, method, status, user_id):
    def _log():
        start_time = datetime.now()
        try:
            logger.debug(f"Kafka 로그 전송 시작: {method} {endpoint} - {status}")
            producer = get_kafka_producer()
            
            log_data = {
                'timestamp': datetime.now().isoformat(),
                'endpoint': endpoint,
                'method': method,
                'status': status,
                'user_id': user_id,
                'message': f"{user_id}가 {method} {endpoint} 호출 ({status})",
                'source': 'aks-demo-backend',
                'thread_id': threading.current_thread().ident,
                'pid': os.getpid()
            }
            
            # Kafka로 전송
            future = producer.send('api-logs', log_data)
            producer.flush(timeout=5)  # 5초 타임아웃
            
            log_time = (datetime.now() - start_time).total_seconds()
            logger.debug(f"Kafka 로그 전송 완료 (소요시간: {log_time:.3f}초)")
            
        except Exception as e:
            log_time = (datetime.now() - start_time).total_seconds()
            logger.error(f"Kafka 로그 전송 실패 (소요시간: {log_time:.3f}초): {str(e)}")
            print(f"Kafka logging error: {str(e)}")
    
    # 새로운 스레드에서 로깅 실행
    thread = Thread(target=_log, name=f"kafka-log-{endpoint}-{method}")
    thread.start()
    logger.debug(f"Kafka 로그 스레드 시작: {thread.name}")
    
    #  # 스레드 풀을 사용하여 작업 실행
    # thread_pool.submit(_log)

# 로그인 데코레이터
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return jsonify({"status": "error", "message": "로그인이 필요합니다"}), 401
        return f(*args, **kwargs)
    return decorated_function

# MariaDB 엔드포인트
@app.route('/db/message', methods=['POST'])
@login_required
def save_to_db():
    try:
        user_id = session['user_id']
        db = get_db_connection()
        data = request.json
        cursor = db.cursor()
        sql = "INSERT INTO messages (message, created_at) VALUES (%s, %s)"
        cursor.execute(sql, (data['message'], datetime.now()))
        db.commit()
        cursor.close()
        db.close()
        
        # 로깅
        log_to_redis('db_insert', f"Message saved: {data['message'][:30]}...")
        
        async_log_api_stats('/db/message', 'POST', 'success', session.get('username', 'unknown'))
        return jsonify({"status": "success"})
    except Exception as e:
        async_log_api_stats('/db/message', 'POST', 'error', session.get('username', 'unknown'))
        log_to_redis('db_insert_error', str(e))
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/db/messages', methods=['GET'])
@login_required
def get_from_db():
    try:
        user_id = session['user_id']
        db = get_db_connection()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT * FROM messages ORDER BY created_at DESC")
        messages = cursor.fetchall()
        cursor.close()
        db.close()
        
        # 비동기 로깅으로 변경
        async_log_api_stats('/db/messages', 'GET', 'success', session.get('username', 'unknown'))
        
        return jsonify(messages)
    except Exception as e:
        if 'user_id' in session:
            async_log_api_stats('/db/messages', 'GET', 'error', session.get('username', 'unknown'))
        return jsonify({"status": "error", "message": str(e)}), 500

# Redis 로그 조회 (읽기 전용 복제본 사용)
@app.route('/logs/redis', methods=['GET'])
def get_redis_logs():
    try:
        # Redis 연결 정보 로깅
        redis_host = os.getenv('REDIS_REPLICA_HOST', 'redis-replicas.sungho.svc.cluster.local')
        redis_password = os.getenv('REDIS_PASSWORD')
        logger.info(f"Redis 연결 시도: host={redis_host}, username=default, password={'*' * len(redis_password) if redis_password else 'None'}")
        
        redis_client = get_redis_readonly_connection()
        
        # Redis ping 테스트
        ping_result = redis_client.ping()
        logger.info(f"Redis ping 성공: {ping_result}")
        
        logs = redis_client.lrange('api_logs', 0, -1)
        redis_client.close()
        
        # 로그가 없으면 샘플 로그 반환
        if not logs:
            sample_logs = [
                {"timestamp": datetime.now().isoformat(), "level": "INFO", "message": "Redis 연결 성공", "service": "redis"},
                {"timestamp": datetime.now().isoformat(), "level": "INFO", "message": "Redis 로그 조회 완료", "service": "redis"}
            ]
            return jsonify(sample_logs)
        
        return jsonify([json.loads(log) for log in logs])
    except Exception as e:
        logger.error(f"Redis 연결 실패: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

# 회원가입 엔드포인트
@app.route('/register', methods=['POST'])
def register():
    logger.info("=== 회원가입 요청 시작 ===")
    try:
        data = request.json
        logger.info(f"요청 데이터: {data}")
        
        username = data.get('username')
        password = data.get('password')
        
        logger.info(f"사용자명: {username}")
        
        if not username or not password:
            logger.warning("사용자명 또는 비밀번호가 누락됨")
            return jsonify({"status": "error", "message": "사용자명과 비밀번호는 필수입니다"}), 400
            
        # 비밀번호 해시화
        logger.info("비밀번호 해시화 중...")
        hashed_password = generate_password_hash(password)
        
        logger.info("데이터베이스 연결 시도...")
        db = get_db_connection()
        cursor = db.cursor()
        
        logger.info("사용자명 중복 체크...")
        # 사용자명 중복 체크
        cursor.execute("SELECT username FROM users WHERE username = %s", (username,))
        existing_user = cursor.fetchone()
        
        if existing_user:
            logger.warning(f"중복된 사용자명: {username}")
            cursor.close()
            db.close()
            return jsonify({"status": "error", "message": "이미 존재하는 사용자명입니다"}), 400
        
        logger.info("새 사용자 데이터 삽입 중...")
        # 사용자 정보 저장
        sql = "INSERT INTO users (username, password) VALUES (%s, %s)"
        cursor.execute(sql, (username, hashed_password))
        db.commit()
        cursor.close()
        db.close()
        
        logger.info(f"회원가입 성공: {username}")
        return jsonify({"status": "success", "message": "회원가입이 완료되었습니다"})
        
    except mysql.connector.Error as db_error:
        logger.error(f"데이터베이스 오류: {str(db_error)}")
        logger.error(f"오류 코드: {db_error.errno}")
        logger.error(f"SQL 상태: {getattr(db_error, 'sqlstate', 'N/A')}")
        return jsonify({"status": "error", "message": f"데이터베이스 오류: {str(db_error)}"}), 500
        
    except Exception as e:
        logger.error(f"일반 오류: {str(e)}")
        logger.error(f"오류 타입: {type(e).__name__}")
        logger.error(f"상세 스택 트레이스: {traceback.format_exc()}")
        return jsonify({"status": "error", "message": str(e)}), 500

# 로그인 엔드포인트
@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.json
        username = data.get('username')
        password = data.get('password')
        
        if not username or not password:
            return jsonify({"status": "error", "message": "사용자명과 비밀번호는 필수입니다"}), 400
        
        db = get_db_connection()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT * FROM users WHERE username = %s", (username,))
        user = cursor.fetchone()
        cursor.close()
        db.close()
        
        if user and check_password_hash(user['password'], password):
            session['user_id'] = user['id']  # 세션에 사용자 ID 저장
            session['username'] = username  # 세션에 사용자명 저장
            
            # Redis 세션 저장 (선택적)
            try:
                redis_client = get_redis_connection()
                session_data = {
                    'user_id': user['id'],
                    'username': username,
                    'login_time': datetime.now().isoformat()
                }
                redis_client.set(f"session:{username}", json.dumps(session_data))
                redis_client.expire(f"session:{username}", 3600)
            except Exception as redis_error:
                print(f"Redis session error: {str(redis_error)}")
                # Redis 오류는 무시하고 계속 진행
            
            return jsonify({
                "status": "success", 
                "message": "로그인 성공",
                "username": username
            })
        
        return jsonify({"status": "error", "message": "잘못된 인증 정보"}), 401
        
    except Exception as e:
        print(f"Login error: {str(e)}")  # 서버 로그에 에러 출력
        return jsonify({"status": "error", "message": "로그인 처리 중 오류가 발생했습니다"}), 500

# 로그아웃 엔드포인트
@app.route('/logout', methods=['POST'])
def logout():
    try:
        if 'user_id' in session:
            username = session.get('username', '')
            if username:
                redis_client = get_redis_connection()
                redis_client.delete(f"session:{username}")
            session.pop('user_id', None)
            session.pop('username', None)
        return jsonify({"status": "success", "message": "로그아웃 성공"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

# 메시지 저장 엔드포인트
@app.route('/messages', methods=['POST'])
@login_required
def save_message():
    try:
        data = request.json
        message_text = data.get('message', '')
        user_id = session['user_id']
        
        if not message_text:
            return jsonify({"status": "error", "message": "메시지 내용은 필수입니다"}), 400
        
        # DB에 메시지 저장
        db = get_db_connection()
        cursor = db.cursor()
        sql = "INSERT INTO messages (user_id, message) VALUES (%s, %s)"
        cursor.execute(sql, (user_id, message_text))
        db.commit()
        cursor.close()
        db.close()
        
        # Redis 로깅 추가
        log_to_redis('message_save', f"Message saved by {session.get('username', 'unknown')}: {message_text[:30]}...")
        
        logger.info(f"메시지 저장 성공: 사용자 {session.get('username', 'unknown')}, 메시지: {message_text}")
        return jsonify({"status": "success", "message": "메시지가 저장되었습니다"})
        
    except Exception as e:
        # 에러 시에도 Redis 로깅
        log_to_redis('message_save_error', f"Error saving message: {str(e)}")
        logger.error(f"메시지 저장 오류: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

# 메시지 검색 (DB에서 검색)
@app.route('/messages/search', methods=['GET'])
@login_required
def search_messages():
    try:
        query = request.args.get('q', '')
        user_filter = request.args.get('user', '')  # 특정 유저로 필터링
        
        # DB에서 검색 (JOIN으로 유저명 포함)
        db = get_db_connection()
        cursor = db.cursor(dictionary=True)
        
        if user_filter:
            # 특정 유저의 메시지만 검색
            sql = """
                SELECT m.id, m.message, m.created_at, u.username 
                FROM messages m 
                JOIN users u ON m.user_id = u.id 
                WHERE m.message LIKE %s AND u.username LIKE %s 
                ORDER BY m.created_at DESC
            """
            cursor.execute(sql, (f"%{query}%", f"%{user_filter}%"))
        else:
            # 모든 메시지 검색
            sql = """
                SELECT m.id, m.message, m.created_at, u.username 
                FROM messages m 
                JOIN users u ON m.user_id = u.id 
                WHERE m.message LIKE %s 
                ORDER BY m.created_at DESC
            """
            cursor.execute(sql, (f"%{query}%",))
        
        results = cursor.fetchall()
        cursor.close()
        db.close()
        
        # Redis 로깅 추가
        log_to_redis('message_search', f"Search query: '{query}', user_filter: '{user_filter}', results: {len(results)}")
        
        logger.info(f"메시지 검색 성공: 쿼리={query}, 유저필터={user_filter}, 결과수={len(results)}")
        return jsonify({"status": "success", "data": results})
        
    except Exception as e:
        # 에러 시에도 Redis 로깅
        log_to_redis('message_search_error', f"Error searching messages: {str(e)}")
        logger.error(f"메시지 검색 오류: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

# 유저별 메시지 조회
@app.route('/messages/user/<username>', methods=['GET'])
@login_required
def get_user_messages(username):
    try:
        # DB에서 특정 유저의 메시지 조회
        db = get_db_connection()
        cursor = db.cursor(dictionary=True)
        sql = """
            SELECT m.id, m.message, m.created_at, u.username 
            FROM messages m 
            JOIN users u ON m.user_id = u.id 
            WHERE u.username = %s 
            ORDER BY m.created_at DESC
        """
        cursor.execute(sql, (username,))
        results = cursor.fetchall()
        cursor.close()
        db.close()
        
        # Redis 로깅 추가
        log_to_redis('user_messages', f"User messages retrieved for: {username}, count: {len(results)}")
        
        logger.info(f"유저별 메시지 조회 성공: {username}, 메시지수={len(results)}")
        return jsonify({"status": "success", "data": results})
        
    except Exception as e:
        # 에러 시에도 Redis 로깅
        log_to_redis('user_messages_error', f"Error retrieving user messages for {username}: {str(e)}")
        logger.error(f"유저별 메시지 조회 오류: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

# 모든 메시지 조회 (관리자용)
@app.route('/messages', methods=['GET'])
@login_required
def get_all_messages():
    try:
        # DB에서 모든 메시지 조회 (JOIN으로 유저명 포함)
        db = get_db_connection()
        cursor = db.cursor(dictionary=True)
        sql = """
            SELECT m.id, m.message, m.created_at, u.username 
            FROM messages m 
            JOIN users u ON m.user_id = u.id 
            ORDER BY m.created_at DESC
        """
        cursor.execute(sql)
        results = cursor.fetchall()
        cursor.close()
        db.close()
        
        # Redis 로깅 추가
        log_to_redis('all_messages', f"All messages retrieved, count: {len(results)}")
        
        logger.info(f"전체 메시지 조회 성공: 메시지수={len(results)}")
        return jsonify({"status": "success", "data": results})
        
    except Exception as e:
        # 에러 시에도 Redis 로깅
        log_to_redis('all_messages_error', f"Error retrieving all messages: {str(e)}")
        logger.error(f"전체 메시지 조회 오류: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

# Kafka 로그 조회 엔드포인트
@app.route('/logs/kafka', methods=['GET'])
@login_required
def get_kafka_logs():
    try:
        consumer = KafkaConsumer(
            'api-logs',
            bootstrap_servers=os.getenv('KAFKA_SERVERS', 'my-kafka:9092'),
            value_deserializer=lambda m: json.loads(m.decode('utf-8')),
            security_protocol='SASL_PLAINTEXT',
            sasl_mechanism='PLAIN',
            sasl_plain_username=os.getenv('KAFKA_USERNAME', 'user1'),
            sasl_plain_password=os.getenv('KAFKA_PASSWORD', ''),
            group_id='api-logs-viewer',
            auto_offset_reset='earliest',
            consumer_timeout_ms=5000
        )
        
        logs = []
        try:
            for message in consumer:
                logs.append({
                    'timestamp': message.value['timestamp'],
                    'endpoint': message.value['endpoint'],
                    'method': message.value['method'],
                    'status': message.value['status'],
                    'user_id': message.value['user_id'],
                    'message': message.value['message']
                })
                if len(logs) >= 100:
                    break
        finally:
            consumer.close()
        
        # 시간 역순으로 정렬
        logs.sort(key=lambda x: x['timestamp'], reverse=True)
        return jsonify(logs)
    except Exception as e:
        print(f"Kafka log retrieval error: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

# 메트릭 엔드포인트
@app.route('/metrics')
def metrics_endpoint():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

# 요청 로깅 및 메트릭 미들웨어
@app.before_request
def log_request_info():
    # 요청 시작 시간 저장
    request.start_time = datetime.now()
    request.request_id = f"{datetime.now().strftime('%Y%m%d%H%M%S')}-{os.getpid()}-{threading.current_thread().ident}"
    
    logger.info("=== 새로운 요청 ===")
    logger.info(f"요청 ID: {request.request_id}")
    logger.info(f"요청 방법: {request.method}")
    logger.info(f"요청 URL: {request.url}")
    logger.info(f"요청 경로: {request.path}")
    logger.info(f"클라이언트 IP: {request.remote_addr}")
    logger.info(f"User-Agent: {request.headers.get('User-Agent', 'N/A')}")
    logger.info(f"Content-Type: {request.headers.get('Content-Type', 'N/A')}")
    logger.info(f"세션 ID: {session.get('user_id', 'anonymous')}")
    
    if request.is_json and request.path not in ['/login', '/register']:  # 민감한 데이터 제외
        logger.debug(f"요청 데이터: {request.get_json()}")
    
    # 활성 연결 수 업데이트
    try:
        redis_client = get_redis_connection()
        active_requests_key = "active_requests"
        redis_client.incr(active_requests_key)
        redis_client.expire(active_requests_key, 300)  # 5분 TTL
        redis_client.close()
    except Exception as e:
        logger.debug(f"활성 요청 수 업데이트 실패: {str(e)}")

@app.after_request
def log_response_info(response):
    # 응답 시간 계산
    if hasattr(request, 'start_time'):
        response_time = (datetime.now() - request.start_time).total_seconds()
        request_id = getattr(request, 'request_id', 'unknown')
        
        # 메트릭 업데이트
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.path,
            status=str(response.status_code)
        ).inc()
        
        REQUEST_DURATION.labels(
            method=request.method,
            endpoint=request.path
        ).observe(response_time)
        
        logger.info(f"요청 ID: {request_id}")
        logger.info(f"응답 상태: {response.status_code}")
        logger.info(f"응답 시간: {response_time:.3f}초")
        logger.info(f"응답 크기: {response.content_length or len(response.get_data())} bytes")
        
        # 느린 요청 경고
        if response_time > 2.0:
            logger.warning(f"느린 요청 감지! {request.method} {request.path} - {response_time:.3f}초")
        
        # 활성 연결 수 감소
        try:
            redis_client = get_redis_connection()
            redis_client.decr("active_requests")
            redis_client.close()
        except Exception as e:
            logger.debug(f"활성 요청 수 감소 실패: {str(e)}")
    
    logger.info("=== 요청 완료 ===")
    return response

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True) 