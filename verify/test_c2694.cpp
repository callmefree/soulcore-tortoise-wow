// 最小复现: 模拟 tortoise-wow WorldSocketMgr.cpp 对 ACE_Singleton 的使用
// MSVC 对模板类隐式析构的 noexcept 推断(noexcept(false))与 ACE_Cleanup 基类
// 析构(=default, noexcept(true))不匹配时触发 C2694
#include <ace/Singleton.h>
#include <ace/Thread_Mutex.h>

class MockWorldSocketMgr
{
public:
    MockWorldSocketMgr() {}
    ~MockWorldSocketMgr() {}
    int dummy() { return 42; }
};

MockWorldSocketMgr* GetMgr()
{
    return ACE_Singleton<MockWorldSocketMgr, ACE_Thread_Mutex>::instance();
}

int main() { return GetMgr() ? 0 : 1; }
