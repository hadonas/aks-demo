# Grafana 대시보드 설정 가이드

## 📊 외부 Grafana 연동 설정

### 1. Grafana 접속
- **URL**: http://grafana.20.249.154.255.nip.io
- **로그인**: admin/admin123 (기본값)

### 2. 데이터소스 설정

#### 2.1 Prometheus 데이터소스 추가
1. Grafana에서 **Configuration** → **Data Sources** 클릭
2. **Add data source** 클릭
3. **Prometheus** 선택
4. 설정:
   ```
   Name: Prometheus
   URL: http://<YOUR_EXTERNAL_IP>:9090
   Access: Server (default)
   ```
5. **Save & Test** 클릭

#### 2.2 Jaeger 데이터소스 추가 (트레이싱용)
1. **Add data source** 클릭
2. **Jaeger** 선택
3. 설정:
   ```
   Name: Jaeger
   URL: http://collector.lgtm.20.249.154.255.nip.io:16686
   Access: Server (default)
   ```
4. **Save & Test** 클릭

### 3. 대시보드 생성

#### 3.1 OpenTelemetry 메트릭 대시보드
1. **+** → **Dashboard** 클릭
2. **Add visualization** 클릭
3. **Prometheus** 데이터소스 선택

**주요 메트릭 쿼리:**
```promql
# 요청률
rate(http_requests_total[5m])

# 응답시간 (95th percentile)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# 에러율
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100

# 활성 사용자
count by (user_id) (http_requests_total)
```

#### 3.2 서비스별 메트릭
```promql
# Backend 서비스 메트릭
rate(http_requests_total{service_name="aks-demo-backend"}[5m])

# Frontend 서비스 메트릭
rate(http_requests_total{service_name="aks-demo-frontend"}[5m])

# 데이터베이스 연결 수
mysql_connections_active

# Redis 연결 수
redis_connected_clients
```

### 4. 알림 설정

#### 4.1 알림 채널 설정
1. **Configuration** → **Alerting** → **Notification channels**
2. **Add channel** 클릭
3. 채널 타입 선택 (Email, Slack, Discord 등)

#### 4.2 알림 규칙 설정
```promql
# 에러율이 5% 이상일 때
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100 > 5

# 응답시간이 1초 이상일 때
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1

# 메모리 사용률이 80% 이상일 때
(container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100 > 80
```

### 5. 대시보드 패널 구성

#### 5.1 Stat 패널 (핵심 지표)
- **Request Rate**: 초당 요청 수
- **Response Time**: 평균 응답시간
- **Error Rate**: 에러율
- **Active Users**: 활성 사용자 수

#### 5.2 Graph 패널 (시계열 데이터)
- **Request Rate Over Time**: 시간별 요청률
- **Response Time Distribution**: 응답시간 분포
- **Error Rate Trend**: 에러율 추이

#### 5.3 Table 패널 (상세 정보)
- **Top Endpoints**: 가장 많이 호출되는 엔드포인트
- **User Activity**: 사용자별 활동
- **Error Details**: 에러 상세 정보

### 6. OpenTelemetry 트레이싱 연동

#### 6.1 Jaeger 연동
1. **Explore** 탭에서 **Jaeger** 데이터소스 선택
2. 서비스 선택: `aks-demo-backend`, `aks-demo-frontend`
3. 트레이스 검색 및 분석

#### 6.2 분산 트레이싱 대시보드
- **Service Map**: 서비스 간 의존성 시각화
- **Trace Timeline**: 요청 흐름 추적
- **Performance Analysis**: 성능 분석

### 7. 유용한 대시보드 템플릿

#### 7.1 Kubernetes 클러스터 모니터링
```promql
# Pod CPU 사용률
rate(container_cpu_usage_seconds_total[5m]) * 100

# Pod 메모리 사용률
container_memory_usage_bytes / container_spec_memory_limit_bytes * 100

# Pod 재시작 횟수
rate(kube_pod_container_status_restarts_total[5m])
```

#### 7.2 애플리케이션 성능 모니터링
```promql
# API 엔드포인트별 응답시간
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{endpoint="/api/messages"}[5m]))

# 데이터베이스 쿼리 성능
histogram_quantile(0.95, rate(mysql_query_duration_seconds_bucket[5m]))

# Redis 캐시 히트율
rate(redis_keyspace_hits_total[5m]) / (rate(redis_keyspace_hits_total[5m]) + rate(redis_keyspace_misses_total[5m])) * 100
```

### 8. 대시보드 공유 및 내보내기

#### 8.1 대시보드 내보내기
1. 대시보드 설정 → **JSON Model** 클릭
2. JSON 복사하여 백업

#### 8.2 대시보드 가져오기
1. **+** → **Import** 클릭
2. JSON 붙여넣기 또는 파일 업로드

### 9. 문제 해결

#### 9.1 데이터소스 연결 실패
- 방화벽 설정 확인
- 네트워크 연결 상태 확인
- URL 형식 확인

#### 9.2 메트릭이 표시되지 않음
- Prometheus 설정 확인
- OpenTelemetry Collector 상태 확인
- 애플리케이션 메트릭 엔드포인트 확인

#### 9.3 트레이싱 데이터 없음
- Jaeger 설정 확인
- OpenTelemetry 설정 확인
- 서비스 간 통신 확인

### 10. 모범 사례

1. **정기적인 백업**: 대시보드 설정 정기 백업
2. **알림 최적화**: 너무 많은 알림 방지
3. **성능 모니터링**: 대시보드 자체 성능 모니터링
4. **보안**: 접근 권한 적절히 설정
5. **문서화**: 대시보드 용도 및 설정 문서화
