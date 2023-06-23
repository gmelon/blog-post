아이템 13에서는 객체의 복제를 위해 사용하는 `Object.clone()` 메서드를 제대로 재정의하기 위해서는 어떻게 해야 하는지에 대해 설명하고 있다. 또한, `Object.clone()` 이 동작하도록 하기 위해 구현해야 하는 Cloneable 인터페이스의 문제점에 대해 이야기하고 결론적으로는 새로운 인터페이스/클래스는 절대 Cloneable을 확장/구현하면 안 되고, 객체의 복제 기능을 구현하기 위해서는 `생성자와 팩토리`를 사용해야 한다는 조언을 하고 있다.

## Object.clone()과 Cloneable의 동작 방식

먼저 이 메서드의 동작 방식에 대해 알아보자. 일반적인 경우와 달리 이 메서드는 선언은 Object 클래스에 되어있지만 빈 인터페이스인 Cloneable을 구현해야만 제대로 작동하도록 설계되어 있다.

>   `CloneNotSupportedException` – if the object's class does not support the Cloneable interface. Subclasses that override the clone method can also throw this exception to indicate that an instance cannot be cloned.
>
>   Object.clone() API 문서, Cloneable을 구현하지 않은 클래스가 clone()을 호출하면 CloneNotSupportedException이 터진다.

```java
// 메서드가 없는 빈 인터페이스인 Cloneable
public interface Cloneable {
}
```

또한, Object.clone()은 protected로 선언되어 하위 클래스에서 재정의해주지 않으면 클라이언트에서 호출할 수 없게 되어있다. 이러한 방식은 상위 클래스에서 정의한 clone()을 동작을 인터페이스가 변경하게 되므로 상당히 이례적인 설계라고 할 수 있지만 실무에서 Cloneable을 구현한 클래스가 흔하게 사용되므로 사용법에 대해서는 알아두는게 좋다고 말한다.

## 올바른 clone() 구현 방법

### 가변 객체를 참조하지 않는 객체

먼저 `모든 필드가 기본 타입이거나 불변 객체를 참조하는 객체` 의 경우 어떻게 clone()을 구현해야 되는지 살펴보자.

이런 경우 먼저 super.clone()을 호출한다. 그럼 그렇게 만들어진 객체가 원본과 똑같은 값을 같는 복제본이 된다. 모든 필드가 기본 타입이거나 불변 객체이므로 이렇게 만들어진 복제본에서 더 이상 수정할 것이 없다. 따라서 그대로 반환해도 된다.

```java
public class Number implements Cloneable {
    private final int value; // 기본 타입
    
    // 생성자 생략
    
    @Override
    public Number clone() {
        try {
            return (Number) super.clone();
        } catch (CloneNotSupportedException e) {
			throw new AssertionError(); // 도달 불가능
        }
    }
}
```

여기서 봐야할 것은 먼저 Object.clone()은 Object를 반환하지만 자바에서는 재정의 시 기존 반환 타입의 하위 타입 반환이 가능하므로 Number를 반환하도록 할 수 있다. 이렇게하면 클라이언트에서 일일이 형변환을 해줄 필요가 없어진다. 또한, Number 클래스가 Cloneable을 구현하고 다른 클래스를 상속받지 않으니 `CloneNotSupportedException`이 터질 일이 없으므로 불필요한 checked exception을 try-catch로 감싸서 메서드의 throws 절을 없애고 클라이언트에서 더 편하게 사용할 수 있도록 해주면 좋다고 한다.

### 가변 객체를 참조하는 객체

만약 참조하는 필드에 가변 객체가 포함된다면 상황이 좀 복잡해진다. 단순히 위에서 했던 것처럼 clone()을 구현하면 어떻게 될까?

```java
public class Stack {
	private Object[] elements;
    
    // 생성자 생략

	// 잘못된 구현
    @Override
    public Stack clone() {
        try {
            return (Stack) super.clone();
        } catch (CloneNotSupportedException e) {
			throw new AssertionError(); // 도달 불가능
        }
    }
    
    // 이후 메서드 생략
}
```

이렇게 clone()을 구현하면 복제된 객체와 원본 객체가 `동일한 주소의 elements 배열을 참조`하는 문제가 생긴다. Object.clone()은 단순히 객체의 주소를 복사해서 새로운 객체에 넣어주기 때문이다. 복사 대상인 객체가 불변인 경우 문제가 되지 않지만 가변인 경우 동일한 객체를 참조하게 되어 한쪽의 변경이 다른 쪽에도 영향을 미쳐 에측할 수 없는 오류를 일으키게 된다.

따라서 아래와 같이 clone() 메서드를 수정해 주어야 한다.

```java
@Override
public Stack clone() {
    try {
        Stack result = (Stack) super.clone();
        result.elements = elements.clone();
        return result;
    } catch (CloneNotSupportedException e) {
		throw new AssertionError(); // 도달 불가능
    }
}
```

>   단, 이 경우 `elements`가 final이 아니어야 한다는 문제가 있으며 이는 `가변 객체를 참조하는 필드는 final로 선언하라`는 일반 용법과 충돌한다. 복제 가능한 클래스 구현을 위해서는 부득이하게 필드에서 final을 제거해야 될 수도 있다.

그런데 만약 HashTable과 같은 클래스의 경우 필드인 배열이 가지고 있는 값이 연결 리스트의 첫번째 엔트리이다. 따라서 이 경우 단순히 배열만 복제한다고 해서 원본 객체와 복제본 객체가 완벽히 분리되지 못한다. 연결리스트를 구성하는 Entry 객체가 동일한 인스턴스가 되어버리므로 복제된 객체의 연결 리스트가 수정되면 당연히 원본 객체의 연결 리스트도 영향을 받는다.

따라서 이런 경우엔, 연결 리스트를 구성하는 모든 엔트리를 새롭게 생성해주는 방식으로 복사를 진행해야 한다.

```java
public class HashTable implements Cloneable {
    private Entry[] buckets = ...;
    
    private static class Entry {
        Object key, value;
        Entry next;
        
		Entry deepCopy() {
            return new Entry(key, value, next == null ? null : next.deepCopy());
        }
    }
    
    @Override public HashTable clone() {
        // try-catch 생략
        HashTable result = (HashTable) super.clone();
        result.buckets = new Entry[buckets.length]; // 새로운 배열 생성
        // 원소(Entry)들과 그 원소들의 next들을 순회하면서
        // 원본과 분리된 연결 리스트를 생성
        for (int i = 0; i < buckets.length ; i++) {
            if (buckets[i] != null) {
                result.buckets[i] = buckets[i].deepCopy();
            }
        }
        return result;
    }
}
```

이렇게 하면 원본이나 복제본의 buckets가 수정되어도 서로에게 영향을 주지 않게 된다.

### + 배열 deep copy

배열.clone()으로 배열을 복사하면 새로운 배열을 만들고 기존 배열의 원소를 채워넣어 반환해주기 때문에 배열의 원소를 삭제하거나 추가해도 서로의 배열엔 영향을 주지 않지만 배열이 갖는 값이 참조 객체인 경우 해당 객체의 값을 수정하면 원본 배열의 객체가 같이 바뀌게 된다. (동일한 인스턴스를 원소로 갖기 때문에)

따라서, 정말 '깊은' 복사를 원한다면 배열.clone()으로는 불충분하고 새롭게 배열을 만들고 내부 원소들을 순회하면서 원소.clone()을 호출해주어야 원소들 각각이 변경되어도 서로에게 영향을 주지 않는다. 즉, 이렇게 하면 기존 배열과 새로운 배열은 내부 원소를 포함해서 전혀 다른 인스턴스가 되는 것이다.

### + 쓰레드 안전 클래스

Object.clone() 은 멀티 쓰레드 환경을 고려하지 않았으므로 쓰레드 안전한 클래스를 만들기 위해서는 clone() 메서드가 아무런 작업도 하지 않더라도 재정의하고 동기화를 해주어야 한다!

### + clone() 에서는 재정의 가능한 메서드 호출 금지

만약 clone() 에서 재정의 가능한 메서드를 호출하게 되면 하위 클래스에서 `super.clone()`을 호출했을 때 상위 클래스의 `clone()`에서 하위 클래스의 **재정의 된** 메서드를 호출하게 되고 예측할 수 없는 복제본이 만들어질 가능성이 생긴다.

```java
public class Parent implements Cloneable {
    
    protected int value = 0;
    
    @Override
    public Parent clone() {
        super.clone();
        // 재정의 가능한 메서드 호출
        overrideableMethod();
        ...
    }
    
    public void overrideableMethod() {
		value += 1;
    }
}

public class Child extends Parent {
    @Override
    public Parent clone() {
		super.clone();
        ...
    }
    
    @Override
    public void overrideableMethod() {
		value += 2;
    }
}
```

위와 같은 상황일 때

```java
Parent instance = new Child();
instance.clone();
```

을 실행하면 실제 인스턴스가 `Child` 이기 때문에 Parent.clone()의 overrideableMethod()는 Child에 선언된 메서드를 호출한다. 즉, `Child.clone() -> Parent.clone() -> Child.overrideableMethod()` 순으로 호출된다. 따라서 Parent 레벨에서 조정되어야 할 값들이 Child에 재정의된 메서드의 동작 방식대로 조정되고 의도치 않은 방향으로 값이 복제되는 문제가 발생할 수 있다.

따라서, clone() 메서드에서는 재정의 가능한 메서드는 호출해서는 안 된다. 메서드 호출이 필요하면 private 도우미 메서드로 만들어서 사용해야 한다.

## 더 나은 방법 - 복사 생성자 & 복사 팩터리

확장하려는 클래스가 Cloneable을 구현한 경우 어쩔 수 없이 clone()을 재정의해줘야 하지만 그렇지 않은 상황에서는 복사 생성자 & 복사 팩터리라는 더 나은 객체 복사 방식을 제공할 수 있다.

>   새로운 인터페이스를 만들 때는 절대 Cloneable을 확장해서는 안 되며, 새로운 클래스도 이를 구현해서는 안 된다.

```java
public class Car {
    
    // 복사 생성자
    public Car(Car car) {
        ...
        return newCar;
    }
    
    // 복사 팩터리
    public static Car newInstance(Car car) {
        ...
        return newCar;
    }
    
}
```

이 방식은 인자를 받기 때문에 구현 클래스가 아니라 인터페이스를 받을 수도 있고, 따라서 해당 인터페이스를 구현하는 클래스끼리는 다른 구현 클래스로의 복사도 가능해진다(HashSet -> TreeSet 등). 개인적으로는 정확하게 복사한다는 것을 명시해줄 수 있는 팩터리 방식이 더 좋아보인다.

>    이펙티브 자바 [전체 아이템 목록](https://github.com/2023-java-study/book-study/tree/main/%EC%9D%B4%ED%8E%99%ED%8B%B0%EB%B8%8C_%EC%9E%90%EB%B0%94) (스터디 정리 레포지토리)