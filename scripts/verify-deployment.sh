#!/usr/bin/env bash
# ============================================================
# 部署后验收脚本
#
# 为什么需要它：
#   `terraform apply` 成功只代表 API 调用成功，不代表业务就绪。
#   user_data 里的 apt-get 是异步执行的，apply 返回时 nginx 可能还没装好。
#   Terraform 管"基础设施存在性"，不管"业务就绪性" —— 这个缺口只能外部验收。
#
# 用法：
#   ./scripts/verify-deployment.sh
#   ./scripts/verify-deployment.sh --wait 180    # 最多等 180 秒
#
# 退出码：0 全部通过；1 有不通过的检查项
# ============================================================
set -euo pipefail

WAIT_SECONDS=120
if [[ "${1:-}" == "--wait" && -n "${2:-}" ]]; then
  WAIT_SECONDS="$2"
fi

SLB_IP="$(terraform output -raw slb_public_ip)"
echo "目标 SLB: ${SLB_IP}"
echo "最长等待: ${WAIT_SECONDS}s"
echo "------------------------------------------------------------"

http_code() {
  curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://${SLB_IP}$1" || echo "000"
}

# ---------- 检查 1：/healthz 可达 ----------
echo "[1/3] SLB /healthz"
deadline=$((SECONDS + WAIT_SECONDS))
ok=0
while (( SECONDS < deadline )); do
  code="$(http_code /healthz)"
  printf '      %s -> %s\n' "$(date +%H:%M:%S)" "$code"
  if [[ "$code" == "200" ]]; then ok=1; break; fi
  sleep 3
done
if (( ok == 0 )); then
  echo "      ❌ /healthz 未在 ${WAIT_SECONDS}s 内返回 200"
  echo "      排查：ss -lntp | grep :80 / journalctl -u nginx / cloud-init status --long"
  exit 1
fi
echo "      ✅ 通过"

# ---------- 检查 2：连续请求是否轮询到两台 ----------
echo "[2/3] 负载均衡轮询（请求 10 次）"
hosts_file="$(mktemp)"
for _ in $(seq 1 10); do
  curl -s --max-time 5 "http://${SLB_IP}/" | grep -o 'from [^ <]*' >> "$hosts_file" || true
done
uniq_count="$(sort -u "$hosts_file" | wc -l | tr -d ' ')"
sort "$hosts_file" | uniq -c
rm -f "$hosts_file"

if [[ "$uniq_count" -ge 2 ]]; then
  echo "      ✅ 两台后端都在服务"
else
  echo "      ⚠️  只命中 ${uniq_count} 台后端，检查另一台的健康状态"
fi

# ---------- 检查 3：后端健康状态 ----------
echo "[3/3] 后端健康状态"
if command -v aliyun >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  lb_id="$(terraform state show -no-color alicloud_slb_load_balancer.slb 2>/dev/null \
           | awk -F= '/^[[:space:]]*id[[:space:]]*=/{gsub(/[ "]/, "", $2); print $2; exit}')"
  if [[ -n "$lb_id" ]]; then
    aliyun slb DescribeHealthStatus --LoadBalancerId "$lb_id" \
      --output cols=ListenerPort,ServerId,ServerHealthStatus
  else
    echo "      - 无法从 state 读取 LB ID，跳过"
  fi
else
  echo "      - 未安装 aliyun CLI 或 jq，跳过（不影响前两项结论）"
fi

echo "------------------------------------------------------------"
echo "验收完成。如需模拟故障，见 README「高可用故障模拟」。"
