<template>
  <div id="app">
    <h1>K8s 마이크로서비스 데모</h1>
    
    <!-- 시스템 모니터링 섹션 (로그인 불필요) -->
    <div class="section">
      <h2>🔍 시스템 모니터링</h2>
      
      <!-- Health Check -->
      <div class="monitoring-subsection">
        <h3>Health Check</h3>
        <button @click="checkHealth" :disabled="loading" class="health-btn">
          {{ loading ? '확인 중...' : '헬스 체크' }}
        </button>
        <div v-if="healthStatus" class="health-result">
          <div class="health-card">
            <h4>시스템 상태: <span :class="healthStatusClass">{{ healthStatus.status }}</span></h4>
            <p><strong>타임스탬프:</strong> {{ formatDate(healthStatus.timestamp) }}</p>
            <div v-if="healthStatus.opentelemetry">
              <h5>OpenTelemetry 상태:</h5>
              <ul>
                <li><strong>Tracer Provider:</strong> {{ healthStatus.opentelemetry.tracer_provider }}</li>
                <li><strong>Meter Provider:</strong> {{ healthStatus.opentelemetry.meter_provider }}</li>
                <li><strong>Endpoint:</strong> {{ healthStatus.opentelemetry.endpoint }}</li>
              </ul>
            </div>
          </div>
        </div>
      </div>

      <!-- OpenTelemetry Test -->
      <div class="monitoring-subsection">
        <h3>OpenTelemetry 테스트</h3>
        <button @click="testOpenTelemetry" :disabled="loading" class="otel-btn">
          {{ loading ? '테스트 중...' : 'OpenTelemetry 테스트' }}
        </button>
        <div v-if="otelTestResult" class="otel-result">
          <div class="otel-card" :class="otelTestResult.status === 'success' ? 'success' : 'error'">
            <h4>테스트 결과: <span>{{ otelTestResult.status }}</span></h4>
            <p><strong>메시지:</strong> {{ otelTestResult.message }}</p>
            <p><strong>타임스탬프:</strong> {{ formatDate(otelTestResult.timestamp) }}</p>
            <p v-if="otelTestResult.endpoint"><strong>엔드포인트:</strong> {{ otelTestResult.endpoint }}</p>
          </div>
        </div>
      </div>

      <!-- Log Test -->
      <div class="monitoring-subsection">
        <h3>로그 전송 테스트</h3>
        <div class="log-test-input">
          <input v-model="logTestMessage" placeholder="테스트 로그 메시지" maxlength="100">
          <button @click="testLogs" :disabled="loading" class="log-btn">
            {{ loading ? '전송 중...' : '로그 테스트' }}
          </button>
        </div>
        <div v-if="logTestResult" class="log-result">
          <div class="log-card" :class="logTestResult.status === 'success' ? 'success' : 'error'">
            <h4>로그 테스트 결과: <span>{{ logTestResult.status }}</span></h4>
            <p><strong>메시지:</strong> {{ logTestResult.message }}</p>
            <p><strong>타임스탬프:</strong> {{ formatDate(logTestResult.timestamp) }}</p>
            <p v-if="logTestResult.logs_sent"><strong>전송된 로그:</strong> {{ logTestResult.logs_sent.join(', ') }}</p>
            <p v-if="logTestResult.test_message"><strong>테스트 메시지:</strong> {{ logTestResult.test_message }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- 로그인/회원가입 섹션 -->
    <div class="section" v-if="!isLoggedIn">
      <div v-if="!showRegister">
        <h2>로그인</h2>
        <input v-model="username" placeholder="사용자명">
        <input v-model="password" type="password" placeholder="비밀번호">
        <button @click="login">로그인</button>
        <button @click="showRegister = true" class="register-btn">회원가입</button>
      </div>
      <div v-else>
        <h2>회원가입</h2>
        <input v-model="registerUsername" placeholder="사용자명">
        <input v-model="registerPassword" type="password" placeholder="비밀번호">
        <input v-model="confirmPassword" type="password" placeholder="비밀번호 확인">
        <button @click="register">가입하기</button>
        <button @click="showRegister = false">로그인으로 돌아가기</button>
      </div>
    </div>

    <div v-else>
      <div class="user-info">
        <span>안녕하세요, {{ username }}님</span>
        <button @click="logout">로그아웃</button>
      </div>

      <div class="container">

        <div class="section">
          <h2>Redis 로그</h2>
          <button @click="getRedisLogs">로그 조회</button>
          <div v-if="redisLogs.length">
            <h3>API 호출 로그:</h3>
            <ul>
              <li v-for="(log, index) in redisLogs" :key="index">
                [{{ formatDate(log.timestamp) }}] {{ log.action }}: {{ log.details }}
              </li>
            </ul>
          </div>
        </div>

        <div class="section">
          <h2>메시지 관리</h2>
          <div class="message-input">
            <input v-model="newMessage" placeholder="새 메시지 입력" @keyup.enter="saveMessage">
            <button @click="saveMessage">메시지 저장</button>
          </div>
          
          <div class="search-section">
            <input v-model="searchQuery" placeholder="메시지 검색">
            <input v-model="userFilter" placeholder="유저명 필터 (선택사항)">
            <button @click="searchMessages">검색</button>
            <button @click="getAllMessages" class="view-all-btn">전체 메시지 보기</button>
            <button @click="getMyMessages" class="my-messages-btn">내 메시지 보기</button>
          </div>
          
          <div v-if="searchResults.length > 0" class="search-results">
            <h3>검색 결과:</h3>
            <table>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>메시지</th>
                  <th>생성 시간</th>
                  <th>사용자</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="result in searchResults" :key="result.id">
                  <td>{{ result.id }}</td>
                  <td>{{ result.message }}</td>
                  <td>{{ formatDate(result.created_at) }}</td>
                  <td>{{ result.username || '알 수 없음' }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios';

// nginx 프록시를 통해 요청하도록 수정
const API_BASE_URL = '/api';

// axios 기본 설정
axios.defaults.timeout = 60000; // 60초 타임아웃
axios.defaults.headers.common['Content-Type'] = 'application/json';
axios.defaults.withCredentials = true;

export default {
  name: 'App',
  data() {
    return {
      username: '',
      password: '',
      isLoggedIn: false,
      searchQuery: '',

      redisLogs: [],
      loading: false,
      showRegister: false,
      registerUsername: '',
      registerPassword: '',
      confirmPassword: '',
      currentUser: null,
      searchResults: [],
      newMessage: '',
      userFilter: '',
      
      // 시스템 모니터링 관련
      healthStatus: null,
      otelTestResult: null,
      logTestResult: null,
      logTestMessage: ''
    }
  },
  computed: {
    // Health status에 따른 CSS 클래스
    healthStatusClass() {
      if (!this.healthStatus) return '';
      return this.healthStatus.status === 'healthy' ? 'status-healthy' : 'status-unhealthy';
    }
  },
  methods: {
    // 날짜를 사용자 친화적인 형식으로 변환
    formatDate(dateString) {
      const date = new Date(dateString);
      return date.toLocaleString();
    },
    
    // Health Check 실행
    async checkHealth() {
      try {
        this.loading = true;
        const response = await axios.get(`${API_BASE_URL}/health`);
        this.healthStatus = response.data;
        console.log('Health check 성공:', this.healthStatus);
      } catch (error) {
        console.error('Health check 실패:', error);
        this.healthStatus = {
          status: 'unhealthy',
          timestamp: new Date().toISOString(),
          error: error.response ? error.response.data.message : error.message
        };
        alert('Health check에 실패했습니다: ' + (error.response ? error.response.data.message : error.message));
      } finally {
        this.loading = false;
      }
    },

    // OpenTelemetry 테스트 실행
    async testOpenTelemetry() {
      try {
        this.loading = true;
        const response = await axios.post(`${API_BASE_URL}/otel/test`);
        this.otelTestResult = response.data;
        console.log('OpenTelemetry 테스트 성공:', this.otelTestResult);
        
        if (this.otelTestResult.status === 'success') {
          alert('OpenTelemetry 테스트가 성공적으로 완료되었습니다! 데이터가 collector로 전송되었습니다.');
        }
      } catch (error) {
        console.error('OpenTelemetry 테스트 실패:', error);
        this.otelTestResult = {
          status: 'error',
          message: error.response ? error.response.data.message : error.message,
          timestamp: new Date().toISOString()
        };
        alert('OpenTelemetry 테스트에 실패했습니다: ' + (error.response ? error.response.data.message : error.message));
      } finally {
        this.loading = false;
      }
    },

    // 로그 테스트 실행
    async testLogs() {
      try {
        this.loading = true;
        const response = await axios.post(`${API_BASE_URL}/logs/test`, {
          message: this.logTestMessage || 'Frontend test log message'
        });
        this.logTestResult = response.data;
        console.log('로그 테스트 성공:', this.logTestResult);
        
        if (this.logTestResult.status === 'success') {
          alert('로그 테스트가 성공적으로 완료되었습니다! Loki에서 로그를 확인할 수 있습니다.');
        }
      } catch (error) {
        console.error('로그 테스트 실패:', error);
        this.logTestResult = {
          status: 'error',
          message: error.response ? error.response.data.message : error.message,
          timestamp: new Date().toISOString()
        };
        alert('로그 테스트에 실패했습니다: ' + (error.response ? error.response.data.message : error.message));
      } finally {
        this.loading = false;
      }
    },

    // Redis에 저장된 API 호출 로그 조회
    async getRedisLogs() {
      try {
        const response = await axios.get(`${API_BASE_URL}/logs/redis`);
        this.redisLogs = response.data;
      } catch (error) {
        console.error('Redis 로그 조회 실패:', error);
      }
    },

    // 사용자 로그인 처리
    async login() {
      try {
        const response = await axios.post(`${API_BASE_URL}/login`, {
          username: this.username,
          password: this.password
        });
        
        if (response.data.status === 'success') {
          this.isLoggedIn = true;
          this.currentUser = this.username;
          this.username = '';
          this.password = '';
        } else {
          alert(response.data.message || '로그인에 실패했습니다.');
        }
      } catch (error) {
        console.error('로그인 실패:', error);
        alert(error.response && error.response.data 
          ? error.response.data.message 
          : '로그인에 실패했습니다.');
      }
    },
    
    // 로그아웃 처리
    async logout() {
      try {
        await axios.post(`${API_BASE_URL}/logout`);
        this.isLoggedIn = false;
        this.username = '';
        this.password = '';
      } catch (error) {
        console.error('로그아웃 실패:', error);
      }
    },

    // 새 메시지 저장
    async saveMessage() {
      if (!this.newMessage.trim()) {
        alert('메시지를 입력해주세요.');
        return;
      }
      
      try {
        this.loading = true;
        const response = await axios.post(`${API_BASE_URL}/messages`, {
          message: this.newMessage
        });
        
        if (response.data.status === 'success') {
          alert('메시지가 저장되었습니다.');
          this.newMessage = '';
          // 저장 후 전체 메시지 새로고침
          await this.getAllMessages();
        } else {
          alert(response.data.message || '메시지 저장에 실패했습니다.');
        }
      } catch (error) {
        console.error('메시지 저장 실패:', error);
        alert('메시지 저장에 실패했습니다.');
      } finally {
        this.loading = false;
      }
    },

    // 메시지 검색 기능 (개선됨)
    async searchMessages() {
      try {
        this.loading = true;
        const params = { q: this.searchQuery };
        if (this.userFilter.trim()) {
          params.user = this.userFilter;
        }
        
        const response = await axios.get(`${API_BASE_URL}/messages/search`, { params });
        
        if (response.data.status === 'success') {
          this.searchResults = response.data.data;
        } else {
          this.searchResults = [];
          alert(response.data.message || '검색에 실패했습니다.');
        }
      } catch (error) {
        console.error('검색 실패:', error);
        alert('검색에 실패했습니다.');
        this.searchResults = [];
      } finally {
        this.loading = false;
      }
    },

    // 전체 메시지 조회 (개선됨)
    async getAllMessages() {
      try {
        this.loading = true;
        const response = await axios.get(`${API_BASE_URL}/messages`);
        
        if (response.data.status === 'success') {
          this.searchResults = response.data.data;
        } else {
          this.searchResults = [];
          alert(response.data.message || '메시지 로드에 실패했습니다.');
        }
      } catch (error) {
        console.error('전체 메시지 로드 실패:', error);
        this.searchResults = [];
      } finally {
        this.loading = false;
      }
    },

    // 내 메시지만 조회
    async getMyMessages() {
      try {
        this.loading = true;
        const response = await axios.get(`${API_BASE_URL}/messages/user/${this.currentUser}`);
        
        if (response.data.status === 'success') {
          this.searchResults = response.data.data;
        } else {
          this.searchResults = [];
          alert(response.data.message || '내 메시지 로드에 실패했습니다.');
        }
      } catch (error) {
        console.error('내 메시지 로드 실패:', error);
        this.searchResults = [];
      } finally {
        this.loading = false;
      }
    },



    // 회원가입 처리
    async register() {
      if (this.registerPassword !== this.confirmPassword) {
        alert('비밀번호가 일치하지 않습니다');
        return;
      }
      
      console.log('회원가입 시작:', {
        username: this.registerUsername,
        url: `${API_BASE_URL}/register`
      });
      
      try {
        console.log('axios 요청 전송 시작...');
        const response = await axios.post(`${API_BASE_URL}/register`, {
          username: this.registerUsername,
          password: this.registerPassword
        }, {
          timeout: 60000,
          headers: {
            'Content-Type': 'application/json'
          }
        });
        
        console.log('서버 응답 받음:', response);
        
        if (response.data.status === 'success') {
          alert('회원가입이 완료되었습니다. 로그인해주세요.');
          this.showRegister = false;
          this.registerUsername = '';
          this.registerPassword = '';
          this.confirmPassword = '';
        } else {
          console.error('회원가입 실패 - 서버 응답:', response.data);
          alert(response.data.message || '회원가입에 실패했습니다.');
        }
      } catch (error) {
        console.error('회원가입 에러 발생:', error);
        console.error('에러 응답:', error.response);
        console.error('에러 요청:', error.request);
        console.error('에러 메시지:', error.message);
        
        if (error.code === 'ECONNABORTED') {
          alert('요청 시간이 초과되었습니다. 다시 시도해주세요.');
        } else if (error.response) {
          alert(error.response.data && error.response.data.message 
            ? error.response.data.message 
            : `서버 오류: ${error.response.status}`);
        } else if (error.request) {
          alert('서버에 연결할 수 없습니다. 네트워크를 확인해주세요.');
        } else {
          alert('알 수 없는 오류가 발생했습니다.');
        }
      }
    }
  }
}
</script>

<style>
.container {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
}

.section {
  margin-bottom: 30px;
  padding: 20px;
  border: 1px solid #ddd;
  border-radius: 5px;
}

input {
  margin-right: 10px;
  padding: 5px;
  width: 300px;
}

button {
  margin-right: 10px;
  padding: 5px 10px;
  background-color: #007bff;
  color: white;
  border: none;
  border-radius: 3px;
  cursor: pointer;
}

button:hover {
  background-color: #0056b3;
}

.sample-btn {
  background-color: #28a745;
}

.sample-btn:hover {
  background-color: #218838;
}

ul {
  list-style-type: none;
  padding: 0;
}

li {
  margin: 5px 0;
  padding: 5px;
  border-bottom: 1px solid #eee;
}

.pagination {
  text-align: center;
  margin-top: 10px;
}

.pagination button {
  padding: 5px 10px;
  background-color: #007bff;
  color: white;
  border: none;
  border-radius: 3px;
  cursor: pointer;
}

.pagination button:hover {
  background-color: #0056b3;
}

.pagination button:disabled {
  background-color: #ccc;
  cursor: not-allowed;
}

.loading-spinner {
  text-align: center;
  margin-top: 20px;
  font-size: 16px;
  color: #555;
}

.user-info {
  text-align: right;
  padding: 10px;
  margin-bottom: 20px;
}

.search-section {
  margin: 10px 0;
}

.search-section input {
  width: 200px;
  margin-right: 10px;
}

.register-btn {
  background-color: #6c757d;
}

.register-btn:hover {
  background-color: #5a6268;
}

.search-results {
  margin-top: 20px;
}

.search-results table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 10px;
}

.search-results th,
.search-results td {
  padding: 12px;
  text-align: left;
  border-bottom: 1px solid #eee;
}

.search-results th {
  background-color: #f8f9fa;
  font-weight: bold;
}

.search-results tr:hover {
  background-color: #f5f5f5;
}

.view-all-btn {
  background-color: #6c757d;
}

.view-all-btn:hover {
  background-color: #5a6268;
}

.message-input {
  margin: 15px 0;
  padding: 15px;
  background-color: #f8f9fa;
  border-radius: 5px;
}

.message-input input {
  width: 300px;
  margin-right: 10px;
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 3px;
}

.message-input button {
  background-color: #28a745;
}

.message-input button:hover {
  background-color: #218838;
}

.my-messages-btn {
  background-color: #17a2b8;
}

.my-messages-btn:hover {
  background-color: #138496;
}

/* 시스템 모니터링 관련 스타일 */
.monitoring-subsection {
  margin-bottom: 25px;
  padding: 15px;
  background-color: #f8f9fa;
  border-radius: 5px;
  border-left: 4px solid #007bff;
}

.monitoring-subsection h3 {
  margin-top: 0;
  color: #495057;
}

.health-btn {
  background-color: #28a745;
}

.health-btn:hover {
  background-color: #218838;
}

.otel-btn {
  background-color: #6f42c1;
}

.otel-btn:hover {
  background-color: #5a32a3;
}

.health-result, .otel-result {
  margin-top: 15px;
}

.health-card, .otel-card {
  padding: 15px;
  border-radius: 5px;
  border: 1px solid #dee2e6;
  background-color: #ffffff;
}

.health-card.success, .otel-card.success {
  border-left: 4px solid #28a745;
  background-color: #f8fff9;
}

.health-card.error, .otel-card.error {
  border-left: 4px solid #dc3545;
  background-color: #fff8f8;
}

.status-healthy {
  color: #28a745;
  font-weight: bold;
}

.status-unhealthy {
  color: #dc3545;
  font-weight: bold;
}

.health-card ul, .otel-card ul {
  margin: 10px 0;
  padding-left: 20px;
}

.health-card li, .otel-card li {
  margin: 5px 0;
  border-bottom: none;
  padding: 2px 0;
}

.health-card h4, .otel-card h4 {
  margin-top: 0;
  margin-bottom: 10px;
}

.health-card h5 {
  margin: 10px 0 5px 0;
  color: #6c757d;
}

/* 로그 테스트 관련 스타일 */
.log-btn {
  background-color: #fd7e14;
}

.log-btn:hover {
  background-color: #e76a05;
}

.log-test-input {
  display: flex;
  gap: 10px;
  margin-bottom: 15px;
  align-items: center;
}

.log-test-input input {
  flex: 1;
  max-width: 300px;
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 3px;
}

.log-result {
  margin-top: 15px;
}

.log-card {
  padding: 15px;
  border-radius: 5px;
  border: 1px solid #dee2e6;
  background-color: #ffffff;
}

.log-card.success {
  border-left: 4px solid #fd7e14;
  background-color: #fff8f0;
}

.log-card.error {
  border-left: 4px solid #dc3545;
  background-color: #fff8f8;
}

.log-card h4 {
  margin-top: 0;
  margin-bottom: 10px;
  color: #495057;
}
</style> 