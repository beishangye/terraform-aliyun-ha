#!/usr/bin/env python3
import pymysql
import sys

# RDS 连接配置（请替换为实际值）
RDS_CONFIG = {
    'host': 'rm-xxxxx.mysql.rds.aliyuncs.com',  # 替换为你的 RDS 地址
    'user': 'app_user',
    'password': 'RDS@Passw0rd2026',
    'database': 'app_database',  # 指定连接到 app_database
    'port': 3306,
    'charset': 'utf8mb4'
}

def test_connection():
    """测试 RDS 连接并执行查询"""
    connection = None
    cursor = None
    try:
        print("🔄 正在尝试连接到 RDS...")
        # 建立连接
        connection = pymysql.connect(**RDS_CONFIG)
        print("✅ 成功连接到 RDS！")
        
        # 创建游标
        cursor = connection.cursor()
        
        # 执行查询 1: 测试基础查询
        print("\n📊 执行查询: SELECT 1")
        cursor.execute("SELECT 1")
        result = cursor.fetchone()
        print(f"✅ 查询结果: {result[0]}")
        
        # 执行查询 2: 查看数据库版本
        print("\n📊 执行查询: SELECT VERSION()")
        cursor.execute("SELECT VERSION()")
        result = cursor.fetchone()
        print(f"✅ MySQL 版本: {result[0]}")
        
        # 执行查询 3: 查看当前数据库
        print("\n📊 执行查询: SELECT DATABASE()")
        cursor.execute("SELECT DATABASE()")
        result = cursor.fetchone()
        print(f"✅ 当前数据库: {result[0]}")
        
        # 执行查询 4: 创建测试表并插入数据
        print("\n📊 执行测试: 创建表并插入数据...")
        cursor.execute("CREATE TABLE IF NOT EXISTS connection_test (id INT, name VARCHAR(50))")
        cursor.execute("INSERT INTO connection_test VALUES (1, 'test1'), (2, 'test2')")
        connection.commit()
        print("✅ 数据插入成功")
        
        # 执行查询 5: 查询刚插入的数据
        print("\n📊 查询测试数据:")
        cursor.execute("SELECT * FROM connection_test")
        rows = cursor.fetchall()
        for row in rows:
            print(f"   ID: {row[0]}, Name: {row[1]}")
        
        # 清理测试数据
        cursor.execute("DROP TABLE connection_test")
        connection.commit()
        print("\n✅ 测试数据已清理")
        
        print("\n🎉 所有测试通过！RDS 连接完全正常。")
        return True
        
    except pymysql.MySQLError as e:
        print(f"❌ MySQL 错误: {e}")
        return False
    except Exception as e:
        print(f"❌ 其他错误: {e}")
        return False
    finally:
        # 关闭连接
        if cursor:
            cursor.close()
        if connection:
            connection.close()
            print("🔒 数据库连接已关闭")

if __name__ == "__main__":
    print("=" * 50)
    print("  RDS MySQL 连接测试工具")
    print("=" * 50)
    
    # 确认配置
    print(f"\n📋 当前配置:")
    print(f"   Host: {RDS_CONFIG['host']}")
    print(f"   User: {RDS_CONFIG['user']}")
    print(f"   Database: {RDS_CONFIG['database']}")
    
    print("\n⚠️  请确认以上配置正确。")
    response = input("是否继续？(y/n): ")
    
    if response.lower() == 'y':
        success = test_connection()
        sys.exit(0 if success else 1)
    else:
        print("已取消测试")
        sys.exit(0)