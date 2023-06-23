인터페이스는 **자신을 구현한 클래스의 인스턴스를 참조할 수 있는 타입**의 역할을 수행한다. Item 22는 인터페이스를 오직 이 용도로만 사용하라고 조언한다.

예를 들어 아래와 같이 아무런 메서드가 선언되어 있지 않은 인터페이스에 상수만 선언해 사용하면 안 된다. (상수 인터페이스 패턴)

```java
public interface SomeConstants {
    int VALUE_ONE = 0;
    int VALUE_TWO = 1;
}
```

이러한 용도로 인터페이스를 사용하게 되면 **내부 구현**이 외부로 그대로 노출되는 것이므로 (인터페이스의 상수는 무조건 public static final) 지양해야 한다. 인터페이스의 목적에 맞지 않는 사용법이라고 할 수 있을 것 같다.

또한 상수를 편하게 사용하기 위해 클라이언트가 인터페이스를 구현하게 되면 상수 인터페이스에 선언된 상수 이름과 구현한 클래스의 네임 스페이스가 섞여 혼란을 주는 문제가 발생한다.

```java
public class MyClass implements SomeConstants {
    public void someMethod() {
        int a = VALUE_ONE; // 인터페이스의 상수
        int VALUE_ONE = 1; // 지역 변수
    }
}
```

## 상수를 공개하는 다른 방법

그럼 의도적으로 상수를 공개하기 위해서는 어떻게 하면 될까?

먼저 특정 클래스, 인터페이스와 강한 연관이 있는 상수라면 해당 클래스, 인터페이스 자체에 상수로 두는 방법이 있다. Integer.MIN_VALUE, Integer.MAX_VALUE가 이에 해당하는 예시이다.

또한, 서로 연관이 있는 여러 개의 상수가 존재하고 상수별로 특정 값을 갖거나 특정 의미를 갖는 경우 열거형을 사용해 표현하는 방법도 고려할 수 있다.

```java
public enum Day {
    MONDAY(0),
    TUESDAY(1),
    WEDNESDAY(2),
    THURSDAY(3),
    FRIDAY(4),
    SATURDAY(5),
    SUNDAY(6);

    private final int value;

    Day(int value) {
        this.value = value;
    }
}
```

만약 이렇게 하는 것도 불가능한 경우라면 별도의 클래스를 만들어서 상수를 모아두되, 인스턴스화가 불가능한 클래스로 만들어서 사용하는 방법도 있다.

```java
public class SomeConstants {
    private SomeConstants() {
		// 인스턴스화, 상속 방지
    }
    public static final int VALUE_ONE = 0;
    public static final int VALUE_TWO = 1;
}
```

인터페이스가 아닌 인스턴스화 불가능한 클래스를 통해 상수를 공개하게 되면 구현을 위해 존재하는 인터페이스와 다르게 상수용 클래스라는 목적을 분명히 밝히고 상속 또한 금지시키면서 부작용을 최소화하며 상수를 공개할 수 있을 것 같다.

>    이펙티브 자바 [전체 아이템 목록](https://github.com/2023-java-study/book-study/tree/main/%EC%9D%B4%ED%8E%99%ED%8B%B0%EB%B8%8C_%EC%9E%90%EB%B0%94) (스터디 정리 레포지토리)