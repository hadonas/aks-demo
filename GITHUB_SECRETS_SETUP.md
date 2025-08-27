# GitHub Secrets 설정 가이드

이 프로젝트를 Azure ACR과 AKS에 배포하기 위해 다음 GitHub Secrets를 설정해야 합니다.

## 필수 Secrets

### 1. ACR 관련 Secrets
- **ACR_REGISTRY**: Azure Container Registry의 로그인 서버 URL
  - 예: `myregistry.azurecr.io`
- **ACR_USERNAME**: ACR의 사용자명
- **ACR_PASSWORD**: ACR의 비밀번호

### 2. Azure 인증 관련 Secrets
- **AZURE_CREDENTIALS**: Azure 서비스 주체의 JSON 형식 인증 정보
  - Azure CLI에서 생성: `az ad sp create-for-rbac --name "aks-demo-sp" --role contributor --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group} --sdk-auth`

### 3. AKS 관련 Secrets
- **AKS_RESOURCE_GROUP**: AKS 클러스터가 위치한 리소스 그룹 이름
- **AKS_CLUSTER_NAME**: AKS 클러스터 이름

## Secrets 설정 방법

1. GitHub 저장소로 이동
2. **Settings** 탭 클릭
3. 왼쪽 메뉴에서 **Secrets and variables** → **Actions** 선택
4. **New repository secret** 버튼 클릭
5. 위의 각 Secret 이름과 값을 입력

## Azure 서비스 주체 생성 명령어

```bash
# Azure CLI로 로그인
az login

# 서비스 주체 생성
az ad sp create-for-rbac \
  --name "aks-demo-sp" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group} \
  --sdk-auth

# 출력된 JSON을 AZURE_CREDENTIALS secret에 복사
```

## ACR 로그인 정보 확인

```bash
# ACR 로그인 정보 확인
az acr credential show --name {acr-name}

# 출력된 username과 password를 각각의 secret에 설정
```

## 주의사항

- 모든 secrets는 민감한 정보이므로 안전하게 보관하세요
- 서비스 주체는 필요한 최소 권한만 부여하세요
- 정기적으로 secrets를 업데이트하세요
