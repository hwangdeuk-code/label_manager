# label_manager

Flutter 기반 레이블 관리 도구입니다. Windows 환경에서 실행되며, MS SQL Server와의 연동을 위해 FFI 및 ODBC를 사용합니다.

## 주요 구성
- Flutter UI 레이어: 사용자 인터페이스와 라벨 관리 기능을 지원하는 화면 및 상태 관리 코드.
- FFI 바인딩: Dart에서 Windows ODBC API를 직접 호출하기 위한 네이티브 연동 계층.
- 데이터 접근 계층: DbClient 추상화를 통해 MS SQL Server 쿼리를 수행하고 결과를 전달합니다.

## MS SQL Server 연동
- FFI를 사용해 네이티브 ODBC 드라이버에 접속하고, 연결/쿼리/결과 처리 전 과정을 Dart에서 제어합니다.
- mssql_connection 모듈은 ODBC 연결을 열고 닫으며, 파라미터 바인딩과 레코드 변환을 담당합니다.
- DbClient 구현체는 외부에서 동일한 인터페이스로 사용할 수 있도록 설계되어, 다른 데이터 소스로의 교체가 용이합니다.

## 개발 노트
- 프로젝트 파일 포맷은 UTF-8 without BOM을 유지합니다.
- 문서와 주석은 한글로 작성합니다.
- 새 기능을 추가할 때는 기존 FFI 인터페이스를 재사용하여 일관된 연결 및 오류 처리를 보장합니다.
- DB 관련 테스트는 로컬 MS SQL Server 인스턴스를 대상으로 수행하며, 접속 정보는 환경 변수 또는 .env 파일로 관리합니다.

## 시작하기
1. Flutter SDK를 설치하고 Flutter doctor로 환경을 확인합니다.
2. Windows ODBC 관리자에서 MS SQL Server용 DSN을 생성합니다.
3. .env 파일에 DSN, 사용자, 암호 등의 접속 정보를 정의합니다.
4. Flutter pub get으로 의존성을 받습니다.
5. Flutter run을 실행하여 애플리케이션을 구동합니다.

## 참고
- ODBC 드라이버는 Microsoft ODBC Driver 17 이상을 권장합니다.
- FFI 문서: https://dart.dev/guides/libraries/c-interop
