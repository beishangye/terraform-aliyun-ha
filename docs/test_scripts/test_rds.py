#!/usr/bin/env python3
"""RDS MySQL 连通性与读写测试。

凭证一律从环境变量读取，不写死在代码里。
（原版本把密码硬编码在 RDS_CONFIG 里，一旦提交就是永久泄漏。）

用法：
    export RDS_HOST=rm-xxxxxxxx.mysql.rds.aliyuncs.com
    export RDS_USER=app_user
    export RDS_PASSWORD='你的密码'
    export RDS_DATABASE=app_database
    export RDS_PORT=3306          # 可选，默认 3306

    python3 test_rds.py

退出码：
    0 全部通过
    1 测试失败
    2 配置缺失 / 依赖缺失
"""

import os
import sys

try:
    import pymysql
except ImportError:
    sys.exit("缺少依赖，请先安装：pip install pymysql")

REQUIRED_ENV = ("RDS_HOST", "RDS_USER", "RDS_PASSWORD")


def load_config() -> dict:
    missing = [k for k in REQUIRED_ENV if not os.getenv(k)]
    if missing:
        sys.exit(f"缺少环境变量：{', '.join(missing)}")

    return {
        "host": os.environ["RDS_HOST"],
        "user": os.environ["RDS_USER"],
        "password": os.environ["RDS_PASSWORD"],
        "database": os.getenv("RDS_DATABASE", "app_database"),
        "port": int(os.getenv("RDS_PORT", "3306")),
        "charset": "utf8mb4",
        "connect_timeout": 10,
    }


def run_tests(cfg: dict) -> bool:
    conn = None
    cur = None
    try:
        print("[1/5] 建立连接 ...")
        conn = pymysql.connect(**cfg)
        cur = conn.cursor()
        print("      连接成功")

        print("[2/5] 基础查询 ...")
        cur.execute("SELECT 1")
        if cur.fetchone()[0] != 1:
            raise RuntimeError("SELECT 1 返回值异常")

        cur.execute("SELECT VERSION()")
        version = cur.fetchone()[0]
        print(f"      MySQL 版本: {version}")

        cur.execute("SELECT DATABASE()")
        print(f"      当前库: {cur.fetchone()[0]}")

        print("[3/5] 连接数检查 ...")
        cur.execute("SHOW STATUS LIKE 'Threads_connected'")
        threads = cur.fetchone()[1]
        cur.execute("SHOW VARIABLES LIKE 'max_connections'")
        max_conn = cur.fetchone()[1]
        used_pct = int(threads) / int(max_conn) * 100
        print(f"      当前连接 {threads} / 上限 {max_conn}（{used_pct:.1f}%）")
        if used_pct > 80:
            print("      ⚠️  连接使用率超过 80%，需要排查连接泄漏或慢查询")

        print("[4/5] 读写测试 ...")
        table = "connection_test"
        cur.execute(f"DROP TABLE IF EXISTS {table}")
        cur.execute(
            f"CREATE TABLE {table} (id INT PRIMARY KEY, name VARCHAR(50)) "
            "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
        )
        cur.execute(f"INSERT INTO {table} VALUES (1, 'test1'), (2, 'test2')")
        conn.commit()
        cur.execute(f"SELECT id, name FROM {table} ORDER BY id")
        rows = cur.fetchall()
        if len(rows) != 2:
            raise RuntimeError(f"写入后读回行数异常：{len(rows)}")
        print(f"      写入并读回 {len(rows)} 行")

        print("[5/5] 清理 ...")
        cur.execute(f"DROP TABLE {table}")
        conn.commit()
        print("      测试表已删除")

        print("\n全部测试通过。")
        return True

    except pymysql.MySQLError as exc:
        print(f"\nMySQL 错误: {exc}")
        if exc.args and exc.args[0] == 1040:
            print("提示：1040 = Too many connections。"
                  "普通账号此时连不进去，请用 root（MySQL 会预留一个连接）"
                  "或阿里云 RDS 控制台的「会话管理」直接 KILL 会话。")
        return False
    except Exception as exc:  # noqa: BLE001
        print(f"\n测试失败: {exc}")
        return False
    finally:
        if cur is not None:
            cur.close()
        if conn is not None:
            conn.close()
            print("连接已关闭")


def main() -> None:
    cfg = load_config()
    print("=" * 52)
    print(" RDS MySQL 连通性测试")
    print("=" * 52)
    print(f"  Host    : {cfg['host']}:{cfg['port']}")
    print(f"  User    : {cfg['user']}")
    print(f"  Database: {cfg['database']}")
    print("  Password: ******（从环境变量读取，不打印）")
    print("=" * 52)
    sys.exit(0 if run_tests(cfg) else 1)


if __name__ == "__main__":
    main()
