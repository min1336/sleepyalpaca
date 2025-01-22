import 'dart:async'; // 비동기 작업 (Future, Stream) 처리
import 'dart:convert'; // JSON 데이터 인코딩 및 디코딩
import 'dart:math'; // 수학적 계산 (랜덤 값, 삼각 함수 등)
import 'package:http/http.dart' as http; // HTTP 요청 처리
import 'package:flutter/material.dart'; // Flutter UI 구성
import 'package:flutter_naver_map/flutter_naver_map.dart'; // 네이버 지도 SDK 사용
import 'package:permission_handler/permission_handler.dart'; // 권한 요청 관리

class NaverMapApp extends StatefulWidget {
  const NaverMapApp({super.key}); // StatefulWidget 생성자

  @override
  State<NaverMapApp> createState() => _NaverMapAppState(); // 상태 관리 클래스 반환
}

class _NaverMapAppState extends State<NaverMapApp> {
  NaverMapController? _mapController; // 네이버 지도 컨트롤러
  final TextEditingController _startController = TextEditingController(); // 출발지 입력 필드 컨트롤러
  List<Map<String, String>> _suggestedAddresses = []; // 자동완성된 주소 목록

  NLatLng? _start; // 출발지 좌표
  List<NLatLng> _waypoints = []; // 경유지 좌표 목록

  double _calculatedDistance = 0.0; // 계산된 총 거리 (km 단위)
  bool _isLoading = false; // 로딩 상태 플래그
  bool _isSearching = false; // 검색 상태 플래그
  double? _selectedDistance; // 선택한 거리 (km)


  final List<String> _searchHistory = [];  // 🔥 최근 검색 기록 추가

  // 최근 검색 기록에 추가 (중복 방지, 최대 5개 유지)
  void _addToSearchHistory(String address) {
    setState(() {
      _searchHistory.remove(address);  // 중복 제거
      _searchHistory.insert(0, address);  // 최근 검색 추가
      if (_searchHistory.length > 5) {
        _searchHistory.removeLast();  // 최대 5개 유지
        _isSearching = false;  // 🔥 입력 중단 시 검색 기록 숨김
      }
    });
  }

  // 🔽 입력 필드 포커스 변경 시 호출되는 함수
  void _onFocusChange(bool hasFocus) {
    setState(() {
      _isSearching = hasFocus; // 포커스 상태에 따라 검색 상태 플래그 변경
    });
  }

  // ✅ 주소 자동완성 결과 선택 시 검색 기록에 추가
  void _onAddressSelected(String address) {
    _startController.text = address;
    _addToSearchHistory(address);  // 🔥 검색 기록에 추가
    setState(() {
      _suggestedAddresses.clear();
    });
  }

  // 🔽 HTML 태그 제거 (자동완성 결과에서 불필요한 태그 제거)
  String _removeHtmlTags(String text) {
    final regex = RegExp(r'<[^>]*>'); // HTML 태그를 찾는 정규식
    return text.replaceAll(regex, '').trim(); // 태그 제거 후 문자열 반환
  }

  // 🔽 네이버 검색 API 호출 (주소 자동완성)
  Future<void> _getSuggestions(String query) async {
    if (query.isEmpty) { // 입력값이 비어 있으면
      setState(() {
        _suggestedAddresses.clear(); // 추천 주소 초기화
      });
      return;
    }

    const clientId = 'SuuXcENvj8j80WSDEPRe'; // 자동완성 api
    const clientSecret = '1KARXNrW1q'; // 자동완성 api secret

    final url =
        'https://openapi.naver.com/v1/search/local.json?query=$query&display=5'; // API 호출 URL

    final response = await http.get(Uri.parse(url), headers: {
      'X-Naver-Client-Id': clientId, // 인증 헤더
      'X-Naver-Client-Secret': clientSecret,
    });

    if (response.statusCode == 200) { // 성공적인 응답 처리
      final data = jsonDecode(response.body); // JSON 디코딩
      final items = data['items'] as List<dynamic>; // 장소 데이터 추출

      setState(() {
        _suggestedAddresses = items.map<Map<String, String>>((item) {
          return {
            'place': _removeHtmlTags(item['title'] ?? '장소 이름 없음'), // 장소 이름
            'address': item['roadAddress'] ?? item['jibunAddress'] ?? '주소 정보 없음', // 주소 정보
          };
        }).toList();
      });
    }
  }

  // 🔽 지도 경로 그리기
  void _drawRoute(Map<String, dynamic> routeData) {
    if (_mapController == null) return; // 지도 컨트롤러가 초기화되지 않았으면 반환

    final List<NLatLng> polylineCoordinates = []; // 경로 좌표 목록 초기화
    final route = routeData['route']['traavoidcaronly'][0]; // 경로 데이터 추출
    final path = route['path']; // 경로의 경로점 목록

    for (var coord in path) { // 경로점 순회
      polylineCoordinates.add(NLatLng(coord[1], coord[0])); // 좌표 추가
    }

    _mapController!.addOverlay(NPolylineOverlay(
      id: 'route', // 오버레이 ID
      color: Colors.lightGreen, // 경로 색상
      width: 4, // 경로 선 두께
      coords: polylineCoordinates, // 경로 좌표
    ));
  }


  Future<List<NLatLng>> _generateWaypoints(NLatLng start, double totalDistance, {int? seed}) async {
    const int numberOfWaypoints = 3; // 경유지 개수
    final Random random = seed != null ? Random(seed) : Random();  // 랜덤 값 생성기 ( 시드값으로 랜덤 반복 방지 )
    final List<NLatLng> waypoints = []; // 경유지 좌표 리스트

    for (int i = 1; i < numberOfWaypoints; i++) {
      final double angle = random.nextDouble() * 2 * pi; // 임의의 방향 ( 0~360도 )
      final double distance = (totalDistance / numberOfWaypoints) * (0.8 + random.nextDouble() * 0.4);
      // 경유지 간 거리 계산 ( 거리 범위 다양화 : 총 거리의 약 0.8 ~ 1.2배 )

      final NLatLng waypoint = await _calculateWaypoint(start, distance, angle); // 새로운 경유지 좌표 계산
      waypoints.add(waypoint); // 경유지 리스트에 추가
    }

    return waypoints; // 생성된 경유지 리스트 반환
  }


  Future<List<NLatLng>> optimizeWaypoints(List<NLatLng> waypoints) async {
    if (waypoints.isEmpty) return waypoints; // 경유지가 없으면 그대로 반환

    List<int> bestOrder = List.generate(waypoints.length, (index) => index); // 기본 순서 생성
    double bestDistance = _calculateTotalDistance(waypoints, bestOrder); // 초기 경로 거리 계산

    bool improved = true; // 최적화 여부 플래그
    while (improved) { // 최적화 반복
      improved = false; // 개선 상태 초기화
      for (int i = 1; i < waypoints.length - 1; i++) { // 모든 경유지 쌍 반복
        for (int j = i + 1; j < waypoints.length; j++) {
          List<int> newOrder = List.from(bestOrder); // 새로운 순서 생성
          newOrder.setRange(i, j + 1, bestOrder.sublist(i, j + 1).reversed); // 경유지 순서 뒤집기
          double newDistance = _calculateTotalDistance(waypoints, newOrder); // 새 경로 거리 계산
          if (newDistance < bestDistance) { // 새로운 경로가 더 짧으면
            bestDistance = newDistance; // 최적 거리 갱신
            bestOrder = newOrder; // 최적 순서 갱신
            improved = true; // 개선 여부 업데이트
          }
        }
      }
    }

    return bestOrder.map((index) => waypoints[index]).toList(); // 최적화된 순서에 따라 경유지 반환
  }

  double _calculateTotalDistance(List<NLatLng> waypoints, List<int> order) {
    double totalDistance = 0.0; // 총 거리 초기화
    for (int i = 0; i < order.length - 1; i++) { // 경유지 쌍 반복
      totalDistance += _calculateDistance(waypoints[order[i]], waypoints[order[i + 1]]);
      // 두 점 간 거리 계산 후 합산
    }
    return totalDistance; // 총 거리 반환
  }

  double _calculateDistance(NLatLng point1, NLatLng point2) {
    const earthRadius = 6371000.0; // 지구 반지름 (미터)
    final dLat = _degreesToRadians(point2.latitude - point1.latitude); // 위도 차이
    final dLon = _degreesToRadians(point2.longitude - point1.longitude); // 경도 차이
    final a = pow(sin(dLat / 2), 2) +
        cos(_degreesToRadians(point1.latitude)) * cos(_degreesToRadians(point2.latitude)) * pow(sin(dLon / 2), 2);
    // 구면 좌표 거리 계산
    final c = 2 * atan2(sqrt(a), sqrt(1 - a)); // 중심 각도
    return earthRadius * c; // 거리 반환
  }

  double _degreesToRadians(double degree) {
    return degree * pi / 180; // 각도를 라디안으로 반환
  }


  Future<NLatLng> _calculateWaypoint(NLatLng start, double distance, double angle) async {
    const earthRadius = 6371000.0; // 지구 반지름
    final deltaLat = (distance / earthRadius) * cos(angle); // 위도 변화량
    final deltaLon = (distance / (earthRadius * cos(start.latitude * pi / 180))) * sin(angle); // 경도 변화량

    final newLat = start.latitude + (deltaLat * 180 / pi); // 새로운 위도
    final newLon = start.longitude + (deltaLon * 180 / pi); // 새로운 경도

    return NLatLng(newLat, newLon); // 새로운 좌표 반환
  }

  Future<NLatLng> getLocation(String address) async {
    const clientId = 'rz7lsxe3oo'; // 네이버 클라이언트 ID
    const clientSecret = 'DAozcTRgFuEJzSX9hPrxQNkYl5M2hCnHEkzh1SBg'; // 네이버 클라이언트 secret ID
    final url = 'https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode?query=${Uri.encodeComponent(address)}';
    // 주소를 기반으로 좌표를 반환하는 API 호출 URL

    final response = await http.get(Uri.parse(url), headers: {
      'X-NCP-APIGW-API-KEY-ID': clientId, // 인증 헤더
      'X-NCP-APIGW-API-KEY': clientSecret, // 인증 헤더
    });

    if (response.statusCode == 200) { // 응답 성공
      final data = jsonDecode(response.body); // JSON 데이터 파싱
      if (data['addresses'] == null || data['addresses'].isEmpty) { // 주소 정보가 없으면 예외 처리
        throw Exception('주소를 찾을 수 없습니다.');
      }
      final lat = double.parse(data['addresses'][0]['y']); // 위도
      final lon = double.parse(data['addresses'][0]['x']); // 경도
      return NLatLng(lat, lon); // 좌표 반환
    } else {
      throw Exception('위치 정보를 불러오지 못했습니다.'); // API 호출 실패 시 예외 발생
    }
  }

// 시작 위치로 카메라 이동
  Future<void> _moveCameraToStart() async {
    if (_mapController != null && _start != null) {
      // 지도 컨트롤러와 시작 위치가 초기화된 경우에만 실행
      await _mapController!.updateCamera(
        NCameraUpdate.withParams(
          target: _start!, // 카메라를 이동시킬 목표 위치 ( 출발지 )
          zoom: 15,  // 적당한 확대 수준
        ),
      );
    }
  }
// ⭐ 지도 위에 총 거리(km) 표시
  // ⭐ 지도 위에 총 거리(km) 표시 (수정 버전)
  void _showTotalDistance(int distanceInMeters) {
    setState(() {
      _calculatedDistance = distanceInMeters / 1000;  // m → km 변환
    });

    if (_mapController == null || _start == null) return;
    // 지도 컨트롤러 또는 시작 위치가 없으면 함수 종료

    _mapController!.addOverlay(
        NMarker(
          id: 'distance_marker', // 마커의 고유 ID
          position: _start!, // 마커를 표시할 위치 ( 출발지 )
        ));
  }

// ⭐ 경유지마다 마커를 추가하는 함수
  void _addWaypointMarkers() {
    if (_mapController == null) return;
    // 지도 컨트롤러가 초기화 되지 않았으면 함수 종료

    for (int i = 0; i < _waypoints.length; i++) {
      // 경유지 리스트를 순회하며 각 경유지에 마커 추가
      final waypoint = _waypoints[i]; // 현재 경유지 좌표

      _mapController!.addOverlay(NMarker(
        id: 'waypoint_marker_$i', // 각 마커의 고유 ID
        position: waypoint, // 마커를 추가할 위치 ( 경유지 좌표 )
        caption: NOverlayCaption(
          text: '${i + 1}', // 마커 위에 표시할 경유지 번호
          textSize: 12.0,
          color: Colors.black,
          haloColor: Colors.white,
        ),
      ));
    }
  }

// _getDirections 함수 수정: 경유지 마커 추가
  Future<void> _getDirections() async {
    if (_mapController == null) return;
    // 지도 컨트롤러가 초기화 되지 않았으면 함수 종료

    await _moveCameraToStart();
    // 카메라를 출발지로 이동

    // 네이버지도 api 클라이언트 정보
    const clientId = 'rz7lsxe3oo';
    const clientSecret = 'DAozcTRgFuEJzSX9hPrxQNkYl5M2hCnHEkzh1SBg';

    // 경유지 좌표를 URL 파라미터 형식으로 변환
    final waypointsParam = _waypoints
        .sublist(0, _waypoints.length - 1) // 마지막 경유지를 제외
        .map((point) => '${point.longitude},${point.latitude}') // 좌표를 문자열료 변환
        .join('|'); // 좌표간 구분

    // 네이버지도 경로 API URL 구성
    final url = 'https://naveropenapi.apigw.ntruss.com/map-direction-15/v1/driving'
        '?start=${_start!.longitude},${_start!.latitude}' // 출발지 좌표
        '&goal=${_start!.longitude},${_start!.latitude}' // 도착지 좌표 ( 출발지와 동일 )
        '&waypoints=$waypointsParam' // 경유지 좌표
        '&option=traavoidcaronly';  // 교통체증 회피

    // API 요청 보내기
    final response = await http.get(Uri.parse(url), headers: {
      'X-NCP-APIGW-API-KEY-ID': clientId,
      'X-NCP-APIGW-API-KEY': clientSecret,
    });

    if (response.statusCode == 200) { // 응답 성공
      final data = jsonDecode(response.body); // 응답 데이터 JSON 디코딩
      _drawRoute(data); // 경로 그리기

      // ✅ trafast → tracomfort로 변경
      final totalDistance = data['route']['traavoidcaronly'][0]['summary']['distance'];
      // 경로의 총 거리 추출
      _showTotalDistance(totalDistance); // 표시

      _addWaypointMarkers(); // 마커 지도에 추가
    }
  }

  @override
  void initState() {
    super.initState();
    _permission();
  }

  void _permission() async {
    var status = await Permission.location.status;
    if (!status.isGranted) {
      await Permission.location.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Running Mate'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context); // 이전 화면으로 돌아가기
            },
          ),
        ),
        body: Stack( // 레이아웃 겹치기 지원
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0), // 간격 조정
                  child: Column(
                    children: [
                      Focus(
                        onFocusChange: _onFocusChange,  // 포커스 변경 처리
                        child: TextField(
                          controller: _startController, // 입력 필드 컨트롤러
                          decoration: InputDecoration(
                            labelText: '출발지 주소 입력', // 입력 필드 라벨
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear), // 입력 초기화 아이콘
                              onPressed: () {
                                _startController.clear(); // 입력 필드 초기화
                                setState(() {
                                  _suggestedAddresses.clear(); // 추천 주소 초기화
                                });
                              },
                            ),
                          ),
                          onChanged: _getSuggestions, // 입력값 변경시 자동완성 호출
                        ),
                      ),
                      // 🔥 입력 중일 때만 최근 검색 기록 표시
                      if (_isSearching && _searchHistory.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                '최근 검색 기록',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                itemCount: _searchHistory.length,
                                itemBuilder: (context, index) {
                                  final historyItem = _searchHistory[index];
                                  return ListTile(
                                    title: Text(historyItem),
                                    leading: const Icon(Icons.history),
                                    onTap: () => _onAddressSelected(historyItem),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      if (_suggestedAddresses.isNotEmpty)
                        Container(
                          height: 200,
                          color: Colors.white,
                          child: ListView.builder(
                            itemCount: _suggestedAddresses.length,
                            itemBuilder: (context, index) {
                              final place = _suggestedAddresses[index]['place']!;
                              final address = _suggestedAddresses[index]['address']!;

                              return ListTile(
                                title: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: place, // 장소 이름
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '\n$address', // 도로명 주소
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey, // 회색 글씨
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                onTap: () => _onAddressSelected(address),
                              );
                            },
                          ),
                        ),
                      DropdownButton<double>(
                        value: _selectedDistance,
                        hint: const Text('달릴 거리 선택 (km)'),
                        items: List.generate(10, (index) {
                          final distance = (index + 1).toDouble();
                          return DropdownMenuItem<double>(
                            value: distance,
                            child: Text('${distance.toStringAsFixed(1)} km'),
                          );
                        }),
                        onChanged: (value) {
                          setState(() {
                            _selectedDistance = value;
                          });
                        },
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          '계산된 총 거리: ${_calculatedDistance.toStringAsFixed(2)} km',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                          FocusScope.of(context).unfocus();  // 🔥 키보드 내리기

                          setState(() {
                            _isLoading = true;  // 🔥 로딩 시작
                          });

                          try {
                            if (_selectedDistance == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('달릴 거리를 선택해 주세요.')),
                              );
                              return;
                            }
                            final totalDistance = _selectedDistance! * 1000;

                            final halfDistance = totalDistance / 2;

                            _start = await getLocation(_startController.text);

                            _addToSearchHistory(_startController.text);  // 🔥 검색 기록에 추가

                            int retryCount = 0;
                            const int maxRetries = 10;  // 🔥 최대 재탐색 횟수

                            bool isRouteFound = false;  // ✅ 경로 성공 여부

                            while (retryCount < maxRetries) {
                              // 🔄 경유지 생성 시 시드 변경 → 비슷한 경로 방지
                              final waypoints = await _generateWaypoints(_start!, halfDistance, seed: DateTime.now().millisecondsSinceEpoch);
                              _waypoints = await optimizeWaypoints(waypoints);

                              await _getDirections();

                              // 🔎 입력 거리와 계산된 거리 비교
                              double difference = (_calculatedDistance * 1000 - totalDistance).abs() / 1000;

                              if (difference <= 0.6) {  // ✅ 오차 허용범위
                                isRouteFound = true;
                                break;
                              } else {
                                retryCount++;
                              }
                            }

                            if (!isRouteFound) {
                              // ❗ 경로 찾기 실패 → 사용자 알림 및 버튼 활성화
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('❗ 최적의 경로를 찾지 못했습니다.\n다시 시도해 주세요.')),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('오류 발생: $e')),
                            );
                          } finally {
                            setState(() {
                              _isLoading = false;  // 🔥 로딩 종료 → 버튼 활성화
                            });
                          }
                        },
                        child: const Text('길찾기'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: NaverMap(
                    options: const NaverMapViewOptions(
                      initialCameraPosition: NCameraPosition(
                        target: NLatLng(37.5665, 126.9780), // 초기 위치 서울
                        zoom: 10, // 초기 확대 수준
                      ),
                      locationButtonEnable: true, // 현재 위치 버튼 활성화
                    ),
                    onMapReady: (controller) {
                      _mapController = controller; // 지도 컨트롤러 초기화
                    },
                  ),
                ),
              ],
            ),
            if (_isLoading)  // 🔥 로딩 인디케이터 표시
              Container(
                color: Colors.black45, // 반투명 배경
                child: const Center(
                  child: CircularProgressIndicator(), // 로딩 애니메이션
                ),
              ),
          ],
        ),
      ),
    );
  }
}