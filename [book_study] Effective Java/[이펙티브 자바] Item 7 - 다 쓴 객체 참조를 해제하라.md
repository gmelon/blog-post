## 개요

자바는 가비지 컬렉터가 있으므로 메모리 관리에 전혀 신경쓰지 않아도 된다고 생각하지만 이는 사실이 아니다! 

예를 들어 스택을 아래와 같이 구현하면 지속적인 메모리 누수가 발생해 프로그램이 종료될 수도 있다.

```java
public class Stack {
    private Object[] elements;
    private int size = 0;
    
    // 생성자
    
    public void push(Object obj) {
        ensureCapacity(); // 배열이 모자라면 늘리기
        elements[size++] = obj;
    }
    
    public Object pop() {
        if (size == 0) {
            throw new EmptyStackException();
        }
        return elements[--size];
    }
}
```

위와 같은 스택은 `elements` 배열이 사라지지 않고 메모리에 계속 누적되며 객체의 참조를 가지고 있게 되므로 가비지 컬렉터가 작동하지 못한다.

### 메모리 관리 방법

가장 간단한 방법은 해당 참조 변수를 null로 선언해버리는 것이다. 그럼 더 이상 Heap 영역에 저장된 객체에 대한 참조가 존재하지 않기 때문에 가비지 컬렉터가 작동할 수 있다. 하지만 명시적으로 변수를 null로 선언하는 것은 가장 마지막에 고려되어야 하고(위 Stack과 같이 `원소 풀을 직접 관리`할 때 사용할 수 있다), 일반적으로는 변수를 `scope 밖으로 밀어버리는 방법`을 사용할 수 있다.

## 캐시

캐시 역시 메모리 누수를 일으키는 주범이다. 캐시에 객체의 참조를 넣고 그대로 잊어버리게 되면 마찬가지로 가비지 컬렉터가 동작할 수 없기 때문에 문제가 발생할 수 있다.

이때는 여러 가지 해법이 있다. 먼저, 키가 참조되는 동안만 엔트리가 살아있는 캐시가 필요한 것이라면 `WeakHashMap`을 사용할 수 있다. 이를 이해하기 위해선 먼저 `참조 유형`에 대해 알아야 한다.

### 참조 유형

*   자바의 참조 유형에는 4가지 종류가 있음
    *   참조 유형에 따라 GC 실행 여부와 시점이 달라짐

#### Strong Reference

*   자바의 기본 참조 유형
*   어떤 변수가 **객체에 대한 참조**를 가지고 있는 한, 해당 객체는 GC의 대상이 되지 않음

```java
MyClass obj = new MyClass(); // obj가 new MyClass() 를 들고 있으므로 GC X

obj = null; // 이 시점부터 new MyClass() 인스턴스가 gc의 대상이 됨
```

#### Soft Reference

*   SoftReference를 통해 들고 있는 경우 (다른 변수에 할당되어 있으면 GC 안 됨, 강한 참조)
*   JVM 메모리가 부족한 **경우에만** gc의 대상이 됨

```java
SoftReference<MyClass> obj = new SoftReference<>(new MyClass());

// 메모리가 부족하면 new MyClass() 인스턴스는 GC의 대상
```

#### Weak Reference

*   WeakReference를 통해 들고 있는 경우 (다른 변수에 할당되어 있으면 GC 안 됨, 강한 참조)
*   JVM 메모리에 **관게 없이** gc의 대상이 됨

```java
WeakReference<MyClass> obj = new WeakReference<>(new MyClass());

// 메모리에 관계 없이 new MyClass() 인스턴스는 항상 GC의 대상
```

#### Phantom Reference

*   생략 (잘 사용되지 않는다고 함)

### WeakHashMap의 동작 방식 

*   Map에 (key, value)를 넣을 때 VO가 아닌 key에 대한 참조가 사라진다면 key를 통해서는 value에 접근할 수 있는 방법이 없다.
    *   하지만 일반적인 HashMap은 value를 계속 가지고 있는다.
*   WeakHashMap은 내부적으로 WeakReference를 사용해 Map에 삽입된 Entry 중 Key에 대한 참조가 null이 될 경우 gc할 때 value까지 삭제한다.

#### WeakHashMap 코드 일부

```java
private static class Entry<K,V> extends WeakReference<Object> implements Map.Entry<K,V> {
    V value;
    final int hash;
    Entry<K,V> next;

   
    Entry(Object key, V value,
          ReferenceQueue<Object> queue,
          int hash, Entry<K,V> next) {
        super(key, queue); // HashMap의 key를 WeakReference의 생성자로 전달한다
        this.value = value;
        this.hash  = hash;
        this.next  = next;
    }
```

#### 동작 예시

```java
WeakHashMap<MyClass, String> map = new WeakHashMap<>();

MyClass obj1 = new MyClass();
MyClass obj2 = new MyClass();

map.put(obj1, "obj1");
map.put(obj2, "obj2");

obj1 = null; // obj1에 대한 참조가 WeakHashMap 내의 WeakReference만 남게 됨 -> gc의 대상이 됨

System.gc(); // 항상 gc를 보장하진 않음, gc가 이뤄졌다고 가정

map.keySet()
    .forEach(key -> System.out.println(map.get(key))); // obj2
```

---

다시 돌아와서 일반적인 캐시는 이와 달리, 유효 기간을 정확히 정의하기 어려우므로 시간이 지날 수록 엔트리의 가치를 떨어뜨리는 방식을 사용해야 한다. 이를 위해 `LinkedHashMap`는 `removeEldestEntry()` 메서드를 제공한다. 기본 구현체는 아래와 같이 false를 반환해 엔트리를 삭제하지 않지만,

```java
protected boolean removeEldestEntry(Map.Entry<K,V> eldest) {
    return false;
}
```

자바에서 제공하는 일부 캐시 클래스들은 LinkedHashMap을 상속받고 이 메서드를 상황에 맞게 재정의해서 사용하도록 구현되어 있는 것 같다. 예를 들어 FileMemData의 내부 클래스 Cache는 아래와 같이 재정의하고 있다.
```java
@Override
protected boolean removeEldestEntry(Map.Entry<K, V> eldest) {
    if (size() < size) {
        return false;
    }
    CompressItem c = (CompressItem) eldest.getKey();
    c.file.compress(c.page);
    return true;
}
```
## 리스너, 콜백

마지막으로 리스너나 콜백을 등록한 후 해제하지 않아도 메모리 누수가 발생할 수 있다. 이러한 문제는 등록되는 참조 객체를 WeakReference로 선언해 해결할 수 있다.

### WeakReference를 적용하지 않은 콜백 예시

```java
@FunctionalInterface
interface Callback {
    void callbackMethod();
}

class Callee {
    private Callback callback;
    
    public void setCallback(Callback callback) {
        this.callback = callback;
    }
    
    private callbackConditional() {
        // 콜백 메서드 호출이 필요한 상황에 호출
        callbackMethod();
    }
}

class Caller {
    private Callee callee;
    private Callback callback = () -> {
        System.out.println("callback method called");
    };
    
    public Caller() {
        callee.setCallback(callback);
    }
}
```

위 코드와 같은 상황이면 Callee가 Callback 객체를 계속해서 강한 참조로 들고 있기 때문에 Caller에서 여러 Callee에 Callback을 등록하면 직접 메서드를 통해 해제하지 않는 이상 Caller가 사라져도 (Callee 쪽에서 참조하기 때문에) Callback 객체가 GC 되지 않는다.

아래와 같이 Callee 쪽에서 `WeakReference<Callback>` 을 사용하면 Caller 가 사라질 때 (Callback에 대한 참조가 Callee의 WeakReference만 남으면) Callback 객체가 GC의 대상이 될 수 있도록 할 수 있다.
### WeakReference를 적용한 콜백 예시

```java
@FunctionalInterface
interface Callback {
    void callbackMethod();
}

class Callee {
    private WeakReference<Callback> callback;
    
    public void setCallback(Callback callback) {
        this.callback = new WeakReference<>(callback);
    }
    
    private callbackConditional() {
        // 콜백 메서드 호출이 필요한 상황에 호출
        callbackMethod();
    }
}

class Caller {
    private Callee callee;
    private Callback callback = () -> {
        System.out.println("callback method called");
    };
    
    public Caller() {
        callee.setCallback(callback);
    }
}
```

>    이펙티브 자바 [전체 아이템 목록](https://github.com/2023-java-study/book-study/tree/main/%EC%9D%B4%ED%8E%99%ED%8B%B0%EB%B8%8C_%EC%9E%90%EB%B0%94) (스터디 정리 레포지토리)

## 참고 자료

*   https://lion-king.tistory.com/entry/Java-%EC%B0%B8%EC%A1%B0-%EC%9C%A0%ED%98%95-Strong-Reference-Soft-Reference-Weak-Reference-Phantom-References
*   https://bepoz-study-diary.tistory.com/340
*   http://www.dreamy.pe.kr/zbxe/CodeClip/3768942