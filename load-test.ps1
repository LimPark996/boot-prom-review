# PowerShell 부하테스트 스크립트
param(
    [int]$Threads = 10,
    [int]$Duration = 30,
    [string]$TargetHost = "localhost",
    [int]$Port = 8080,
    [string]$Path = "/200"
)

$url = "http://${TargetHost}:${Port}${Path}"
$endTime = (Get-Date).AddSeconds($Duration)

Write-Host "Starting load test..."
Write-Host "URL: $url"
Write-Host "Threads: $Threads"
Write-Host "Duration: $Duration seconds"
Write-Host "Start time: $(Get-Date)"

# 결과 수집용 변수
$totalRequests = 0
$successRequests = 0
$errorRequests = 0
$responseTimes = @()

# 병렬 작업 정의
$scriptBlock = {
    param($url, $endTime)

    $requests = 0
    $success = 0
    $errors = 0
    $times = @()

    while ((Get-Date) -lt $endTime) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            $response = Invoke-WebRequest -Uri $url -Method GET -TimeoutSec 5 -UseBasicParsing
            $stopwatch.Stop()

            $requests++
            if ($response.StatusCode -eq 200) {
                $success++
            } else {
                $errors++
            }
            $times += $stopwatch.ElapsedMilliseconds
        }
        catch {
            $stopwatch.Stop()
            $requests++
            $errors++
            $times += $stopwatch.ElapsedMilliseconds
        }

        Start-Sleep -Milliseconds 10  # 요청 간격 조절
    }

    return @{
        Requests = $requests
        Success = $success
        Errors = $errors
        ResponseTimes = $times
    }
}

# 병렬 실행
$jobs = @()
for ($i = 0; $i -lt $Threads; $i++) {
    $jobs += Start-Job -ScriptBlock $scriptBlock -ArgumentList $url, $endTime
}

# 작업 완료 대기
$jobs | Wait-Job | Out-Null

# 결과 수집
foreach ($job in $jobs) {
    $result = Receive-Job $job
    $totalRequests += $result.Requests
    $successRequests += $result.Success
    $errorRequests += $result.Errors
    $responseTimes += $result.ResponseTimes
    Remove-Job $job
}

# 결과 출력
$actualDuration = $Duration
$rps = [math]::Round($totalRequests / $actualDuration, 2)
$avgResponseTime = if ($responseTimes.Count -gt 0) { [math]::Round(($responseTimes | Measure-Object -Average).Average, 2) } else { 0 }
$minResponseTime = if ($responseTimes.Count -gt 0) { ($responseTimes | Measure-Object -Minimum).Minimum } else { 0 }
$maxResponseTime = if ($responseTimes.Count -gt 0) { ($responseTimes | Measure-Object -Maximum).Maximum } else { 0 }
$errorRate = [math]::Round(($errorRequests / $totalRequests) * 100, 2)

Write-Host "`n========== LOAD TEST RESULTS =========="
Write-Host "End time: $(Get-Date)"
Write-Host "Total Requests: $totalRequests"
Write-Host "Successful Requests: $successRequests"
Write-Host "Failed Requests: $errorRequests"
Write-Host "Requests per Second: $rps"
Write-Host "Error Rate: $errorRate%"
Write-Host "Response Time (ms):"
Write-Host "  - Average: $avgResponseTime"
Write-Host "  - Minimum: $minResponseTime"
Write-Host "  - Maximum: $maxResponseTime"
Write-Host "========================================"