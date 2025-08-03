# 저장된 리스트 페이지 HTML
def saved_list_html(user_info, saved_list)
  total_weight = saved_list.sum { |item| (item['weight_net'] || 0).to_f }
  
  html_content = <<-HTML
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DSHI Dashboard - 저장된 리스트</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #f5f5f5; min-height: 100vh;
        }
        .header {
            background: linear-gradient(135deg, #2196F3 0%, #21CBF3 100%);
            color: white; padding: 15px 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .header-content {
            max-width: 1200px; margin: 0 auto; display: flex; justify-content: space-between; align-items: center;
        }
        .header h1 { font-size: 24px; font-weight: 500; }
        .user-info { font-size: 14px; }
        .nav-btn, .logout-btn {
            background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.3);
            color: white; padding: 8px 16px; border-radius: 6px; text-decoration: none;
            transition: all 0.3s; margin-left: 10px;
        }
        .nav-btn:hover, .logout-btn:hover { background: rgba(255,255,255,0.3); }
        .container { max-width: 1200px; margin: 20px auto; padding: 0 20px; }
        .card {
            background: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin-bottom: 20px; overflow: hidden;
        }
        .card-header {
            background: #f8f9fa; padding: 20px; border-bottom: 1px solid #e9ecef;
            font-size: 18px; font-weight: 600; color: #333;
        }
        .card-body { padding: 20px; }
        .btn {
            padding: 10px 20px; border: none; border-radius: 6px; cursor: pointer;
            font-size: 14px; font-weight: 500; transition: all 0.3s; text-decoration: none;
            display: inline-block; text-align: center; margin-right: 10px;
        }
        .btn-primary { background: #2196F3; color: white; }
        .btn-success { background: #28a745; color: white; }
        .btn-danger { background: #dc3545; color: white; }
        .btn:hover { transform: translateY(-1px); box-shadow: 0 4px 8px rgba(0,0,0,0.15); }
        .btn:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }
        table { width: 100%; border-collapse: collapse; border: 1px solid #ddd; }
        th, td { padding: 12px; border: 1px solid #ddd; text-align: left; }
        th { background: #f8f9fa; font-weight: 600; }
        tr:hover { background-color: #f8f9fa; }
        .summary-info {
            background: #e3f2fd; padding: 20px; border-radius: 8px; margin-bottom: 20px;
            border-left: 4px solid #2196F3;
        }
        .checkbox-cell { text-align: center; width: 50px; }
        .item-checkbox { transform: scale(1.2); cursor: pointer; }
        .empty-state {
            text-align: center; padding: 60px 20px; color: #666;
        }
        .empty-state h3 { margin-bottom: 10px; color: #333; }
    </style>
</head>
<body>
    <div class="header">
        <div class="header-content">
            <h1>🏭 DSHI Dashboard</h1>
            <div class="user-info">
                👤 #{user_info['username']}님 (Level #{user_info['permission_level']})
                <a href="/" class="nav-btn">🔍 조립품 검색</a>
                <a href="/inspection-requests" class="nav-btn">📊 검사신청 조회</a>
                <a href="/logout" class="logout-btn">로그아웃</a>
            </div>
        </div>
    </div>

    <div class="container">
        <div class="card">
            <div class="card-header">
                📋 저장된 리스트
            </div>
            <div class="card-body">
HTML

  if saved_list.empty?
    html_content += <<-HTML
                <div class="empty-state">
                    <h3>📭 저장된 항목이 없습니다</h3>
                    <p>조립품 검색에서 항목을 선택하고 저장해보세요.</p>
                    <a href="/" class="btn btn-primary" style="margin-top: 20px;">🔍 조립품 검색하기</a>
                </div>
HTML
  else
    html_content += <<-HTML
                <div class="summary-info" id="summaryInfo">
                    <strong>📊 요약 정보:</strong> 총 #{saved_list.size}개 항목 | 총 중량: #{total_weight.round(2)} kg
                </div>
                
                <div style="background: #e3f2fd; padding: 20px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #2196F3;">
                    <h4 style="margin-bottom: 15px;">🔍 검사신청</h4>
                    <div style="display: flex; gap: 15px; align-items: end;">
                        <div>
                            <label style="display: block; margin-bottom: 8px; font-weight: 500;">검사신청일</label>
                            <input type="date" id="inspectionDate" 
                                   style="padding: 10px; border: 2px solid #e1e5e9; border-radius: 6px; font-size: 14px;"
                                   min="#{Date.today.strftime("%Y-%m-%d")}"
                                   value="#{(Date.today + 1).strftime("%Y-%m-%d")}">
                        </div>
                        <div>
                            <button id="createInspectionBtn" class="btn btn-success" disabled>검사신청</button>
                        </div>
                        <div>
                            <button id="removeSelectedBtn" class="btn btn-danger" disabled>선택항목 삭제</button>
                        </div>
                    </div>
                    <div id="selectedInfo" style="margin-top: 15px; font-size: 14px; color: #666;">
                        선택된 항목: 0개
                    </div>
                </div>

                <div style="overflow-x: auto;">
                    <table id="savedListTable">
                        <thead>
                            <tr>
                                <th class="checkbox-cell">
                                    <input type="checkbox" id="selectAllCheckbox">
                                </th>
                                <th>조립품 코드</th>
                                <th>Zone</th>
                                <th>Item</th>
                                <th>Weight(NET)</th>
                                <th>Status</th>
                                <th>Last Process</th>
                            </tr>
                        </thead>
                        <tbody id="savedListBody">
HTML
    
    saved_list.each_with_index do |assembly, index|
      html_content += <<-HTML
                            <tr>
                                <td class="checkbox-cell">
                                    <input type="checkbox" class="item-checkbox" data-index="#{index}" data-assembly='#{assembly.to_json}'>
                                </td>
                                <td>#{assembly['name'] || 'N/A'}</td>
                                <td>#{assembly['location'] || 'N/A'}</td>
                                <td>#{assembly['drawing_number'] || 'N/A'}</td>
                                <td style="text-align: right;">#{assembly['weight_net'] || '0'}</td>
                                <td>#{assembly['status'] || '-'}</td>
                                <td>#{assembly['lastProcess'] || '-'}</td>
                            </tr>
HTML
    end
    
    html_content += <<-HTML
                        </tbody>
                    </table>
                </div>
HTML
  end

  html_content += <<-HTML
            </div>
        </div>
    </div>

    <script>
        function updateSelectionButtons() {
            const selected = document.querySelectorAll('.item-checkbox:checked');
            const removeBtn = document.getElementById('removeSelectedBtn');
            const inspectionBtn = document.getElementById('createInspectionBtn');
            const selectedInfo = document.getElementById('selectedInfo');
            const summaryInfo = document.getElementById('summaryInfo');
            
            if (removeBtn) removeBtn.disabled = selected.length === 0;
            if (inspectionBtn) inspectionBtn.disabled = selected.length === 0;
            if (selectedInfo) selectedInfo.textContent = `선택된 항목: ${selected.length}개`;
            
            // 요약 정보 동적 업데이트
            if (summaryInfo && selected.length > 0) {
                let selectedWeight = 0;
                Array.from(selected).forEach(checkbox => {
                    const assembly = JSON.parse(checkbox.dataset.assembly);
                    selectedWeight += parseFloat(assembly.weight_net || 0);
                });
                summaryInfo.innerHTML = `<strong>📊 요약 정보:</strong> 선택된 ${selected.length}개 항목 | 선택된 중량: ${selectedWeight.toFixed(2)} kg`;
            } else if (summaryInfo) {
                summaryInfo.innerHTML = `<strong>📊 요약 정보:</strong> 총 #{saved_list.size}개 항목 | 총 중량: #{total_weight.round(2)} kg`;
            }
        }

        document.addEventListener('DOMContentLoaded', function() {
            const selectAllCheckbox = document.getElementById('selectAllCheckbox');
            
            if (selectAllCheckbox) {
                selectAllCheckbox.addEventListener('change', function() {
                    const isChecked = this.checked;
                    document.querySelectorAll('.item-checkbox').forEach(checkbox => {
                        checkbox.checked = isChecked;
                    });
                    updateSelectionButtons();
                });
            }

            document.querySelectorAll('.item-checkbox').forEach(checkbox => {
                checkbox.addEventListener('change', updateSelectionButtons);
            });

            const removeSelectedBtn = document.getElementById('removeSelectedBtn');
            if (removeSelectedBtn) {
                removeSelectedBtn.addEventListener('click', function() {
                    const selected = document.querySelectorAll('.item-checkbox:checked');
                    if (selected.length > 0 && confirm(`선택된 ${selected.length}개 항목을 삭제하시겠습니까?`)) {
                        const indices = Array.from(selected).map(cb => parseInt(cb.dataset.index));
                        location.href = '/api/remove-from-saved-list?indices=' + indices.join(',');
                    }
                });
            }

            const createInspectionBtn = document.getElementById('createInspectionBtn');
            if (createInspectionBtn) {
                createInspectionBtn.addEventListener('click', async function() {
                    const selected = document.querySelectorAll('.item-checkbox:checked');
                    const inspectionDate = document.getElementById('inspectionDate').value;
                    
                    if (selected.length === 0) {
                        alert('검사신청할 항목을 선택해주세요.');
                        return;
                    }
                    
                    if (!inspectionDate) {
                        alert('검사신청일을 선택해주세요.');
                        return;
                    }
                    
                    const selectedData = Array.from(selected).map(cb => JSON.parse(cb.dataset.assembly));
                    
                    if (!confirm(`${selected.length}개 항목을 ${inspectionDate}로 검사신청하시겠습니까?`)) {
                        return;
                    }
                    
                    try {
                        const response = await fetch('/api/create-inspection-request', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({
                                assemblies: selectedData,
                                inspection_date: inspectionDate
                            })
                        });
                        
                        const result = await response.json();
                        
                        if (result.success) {
                            alert(`✅ 검사신청이 성공적으로 생성되었습니다!\\n\\n📋 신청 항목: ${selectedData.length}개\\n📅 검사일: ${inspectionDate}`);
                            location.reload();
                        } else {
                            alert(`❌ 검사신청 실패: ${result.error}`);
                        }
                    } catch (error) {
                        alert(`❌ 검사신청 오류: ${error.message}`);
                    }
                });
            }
        });
    </script>
</body>
</html>
HTML

  return html_content
end