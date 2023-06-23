## 태그 달린 클래스

아래와 같이 내부적으로 특정 필드 (태그 역할)을 갖고 이 필드에 값에 따라 다른 동작을 수행하는 클래스를 책에선 '태그 달린 클래스'라고 표현하고 있다.

```java
public class Figure {
    public enum Shape {RECTANGLE, CIRCLE};
    private final Shape shape; // 태그
    
    // RECTANGLE용 필드
    private double length;
    private double width;
    
    // CIRCLE용 필드
    private double radius;

    // RECTANGLE용 생성자
    public Figure(double length, width) {
        ...
    }
    
    // CIRCLE용 생성자
    public Figure(double radius) {
        ...
    }
    
    // Shape에 따라 로직이 달라지는 메서드
    public double area() {
        switch(shape) {
            case A:
                ...
                return ...;
            case B:
                ...
                return ...;
        }
    }
}
```

이런 식으로 내부 필드에 따라 서로 다른 분기를 타는 클래스를 말하는데 물론 이러한 클래스는 단점이 매우 많다. 먼저 가장 눈에 띄는 것은 switch를 사용한 분기 코드이다.

만약 새로운 의미를 추가하려면 클래스에서 Shape를 사용하는 모든 코드를 찾아 코드를 추가해주어야 한다. 현재는 area() 메서드만 Shape에 따른 분기를 사용하고 있지만 이러한 코드가 많을 경우 이를 모두 찾아 새로운 의미에 대한 코드를 추가해주어야 한다. 이 과정에서 누락되거나 실수를 해서 오류가 발생할 가능성이 높다.

또한 각 의미 별로 필요한 필드가 다르기 때문에 하나의 클래스에 모든 의미에 해당하는 필드와 생성자가 위치하게 되어 코드가 불필요하게 복잡해진다.

## 클래스 계층구조

그럼 이를 클래스 계층 구조로 전환해보자. 방법은 아래와 같다.

1.   계층 구조의 루트가 될 **추상 클래스**를 정의
2.   태그 값에 따라 달라지는 메서드는 추상 클래스의 **추상 메서드**
3.   태그와 관계없는 메서드/필드는 추상 클래드에 **일반 메서드/필드**로 둠

따라서 위 예시의 경우 아래와 같이 분리할 수 있다.

#### Figure 추상 클래스

```java
public abstract class Figure {
    // 태그 값에 따라 동작이 달라지는 메서드
    abstract double area();
}
```

#### Circle extends Figure

```java
public Circle extends Figure {
    private final double radius;
    
    public Circle(...) {
        ...
    }

    // 각자의 의미에 맞게 추상 메서드 구현    
    @Override
    public double area {
        return ...;
    }
}
```

#### Rectangle extends Figure

```java
public Rectangle extends Figure {
    private final double length;
    private final double width;
    
    public Rectangle(...) {
        ...
    }
    
    // 각자의 의미에 맞게 추상 메서드 구현
    @Override
    public double area {
        return ...;
    }
}
```

이런 식으로 계층 구조를 활용하면 의미별 타입이 별도로 존재하게 되어 특정 의미만 매개변수로 받도록 제한할 수 있게 된다. 예를 들어 Rectangle 하위에 정사각형 Square 클래스가 있을 때 어떤 메서드가 아래와 같다면 Circle이 아닌 Rectangle 하위 계층의 클래스들만 지원한다고 명시할 수 있게 된다.

```java
public void someMethod(Rectangle rectangle) {
    ...
}
```

또, 결국 모두 루트 클래스인 Figure을 상속받기 때문에 동일한 타입으로 사용할 수 있는 등 유연성을 제공한다.

>    이펙티브 자바 [전체 아이템 목록](https://github.com/2023-java-study/book-study/tree/main/%EC%9D%B4%ED%8E%99%ED%8B%B0%EB%B8%8C_%EC%9E%90%EB%B0%94) (스터디 정리 레포지토리)