// 最小复现 v2: 模拟真实触发条件
// 真实场景: WorldSocketMgr : MangosSocketMgr<WorldSocket> (基类有用户声明的析构)
//           WorldSocketMgr.cpp 用 ACE_Singleton<WorldSocketMgr, ACE_Thread_Mutex>
// 编译模式: MSVC 默认 /std:c++14 (CMake 未指定 CXX_STANDARD 时), 非 c++17
#include <ace/Singleton.h>
#include <ace/Thread_Mutex.h>

// 模拟 MangosSocketMgr: 模板基类, 有用户声明的析构函数(声明+定义分离)
template <typename T>
class MockMgrBase
{
public:
    MockMgrBase();
    ~MockMgrBase();

    T* m_ptr;
};

template <typename T>
MockMgrBase<T>::MockMgrBase() : m_ptr(0) {}

template <typename T>
MockMgrBase<T>::~MockMgrBase() { delete m_ptr; }

// 模拟 WorldSocketMgr: 继承带用户析构的模板基类, 被 ACE_Singleton 包装
class WorldSocketMgrLike : public MockMgrBase<int>
{
public:
    WorldSocketMgrLike() {}
    int dummy() { return 42; }
};

WorldSocketMgrLike* GetMgr()
{
    return ACE_Singleton<WorldSocketMgrLike, ACE_Thread_Mutex>::instance();
}

int main() { return GetMgr() ? 0 : 1; }
