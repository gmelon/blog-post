## 개요

정적 메서드와 정적 필드만을 담은 클래스는 객체 지향적으로 보이지 않긴하지만 자바 API의 Arrays나 Collections가 그런 것처럼 특정 인터페이스를 구현하는 객체의 정적 팩토리 메서드를 넣어둘 수도 있고 (자바 8부터는 인터페이스에서도 가능) 상속이 불가능한 final 클래스와 관련된 메서드를 구현하고 모아둘 때도 사용한다.

이러한 클래스는 인스턴스로 만들어 쓰려고 설계한게 아니다. 하지만 생성자를 명시하지 않으면 컴파일러가 자동으로 기본 생성자를 만들어준다.

#### 컴파일 전

```java
public class UtilClass {
    private static int value = 0;

    public static int getValue() {
        return value;
    }
}
```

#### 컴파일 후

```java
public class UtilClass {
    private static int value = 0;

    public UtilClass() {
    }

    public static int getValue() {
        return value;
    }
}
```

## 해결 방안

이러한 일을 방지하기 위해 private 생성자를 만들어주자. 그럼 컴파일러가 자동으로 기본 생성자를 만들지 않기 때문에 불필요한 인스턴스화를 막을 수 있다.

```java
public class UtilClass {
    private static int value = 0;

    private UtilClass() {
        throw new AssertionError();
    }
    
    public static int getValue() {
        return value;
    }
}
```

위 코드처럼 예외 까지 던져주면 실수로 내부에서 인스턴스를 생성하는 것도 방지할 수 있다.

## 상속 방지 효과

private 생성자만 하나 두는 방식은 상속을 금지시키는 효과도 있다. 모든 클래스의 생성자는 명시/묵시적으로 상위 클래스의 생성자를 super()를 통해 호출해야 하는데 private 생성자는 자식에서도 호출이 불가능하니 상속이 불가능해진다.

>    이펙티브 자바 [전체 아이템 목록](https://github.com/2023-java-study/book-study/tree/main/%EC%9D%B4%ED%8E%99%ED%8B%B0%EB%B8%8C_%EC%9E%90%EB%B0%94) (스터디 정리 레포지토리)