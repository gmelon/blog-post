## 정적 팩토리 메서드란

정적 팩토리 메서드는 클래스에서 **인스턴스를 생성**하는 용도로 생성자와 별도로 제공할 수 있는 또 다른 수단이다. 예를 들어 Boolean 클래스의 경우 아래와 같이 인스턴스를 생성할 수 있는 정적 팩토리 메서드를 제공한다.

```java
public static Boolean valueOf(boolean b) {
    return b ? Boolean.TRUE : Boolean.FALSE;
}
```

### 정적 팩토리 메서드의 장점

그럼 생성자 대신 정적 팩토리 메서드를 사용할 때 어떤 장점이 있을까? 책에서는 크게 5가지를 제시한다.

1.   이름을 가질 수 있다.

인스턴스를 생성하는 메서드가 이름을 가지게 되면 **반환될 객체의 특성을 쉽고 정확하게 묘사**할 수 있다는 장점이 생긴다. 예를 들어 BigInteger의 probablePrime() 이라는 정적 팩토리 메서드는 **소수인 BigInteger의 인스턴스를 반환한다** 라고 하는 반환 객체의 특성을 명확하게 드러낼 수 있다.

2.   인스턴스 통제가 가능해진다.

반복되는 요청에 동일한 (캐싱된) 객체를 반환하거나 아예 인스턴스화를 금지하는 등 정적 팩토리 메서드를 사용하면 생성자에서는 할 수 없는 **인스턴스 통제**가 가능해진다. 예를 들어 아래 LotteryNumber 클래스의 경우 무조건 필드인 lotteryNumber 값이 1~45임이 보장되어 있기 때문에 해당 값들을 갖는 인스턴스를 static 초기화 블럭에서 미리 만들어두고 정적 팩토리 메서드를 통해 인스턴스를 요청하게 되면 매번 새로운 인스턴스를 반환하지 않고 이미 만들어진 값을 반환하는 식으로 동작하게 할 수 있다. 이러한 방식은 특히 인스턴스의 생성 비용이 클 경우에 성능을 향상시킬 수 있게 해준다.

```java
public class LotteryNumber implements Comparable<LotteryNumber>{

    public static final int LOTTERY_NUM_MIN = 1;
    public static final int LOTTERY_NUM_MAX = 45;
    public static Map<Integer, LotteryNumber> lotteryNumbers = new HashMap<>();

    private final int lotteryNumber;

    // 클래스 로드 시 인스턴스를 미리 생성해둠
    static {
        for (int i = LOTTERY_NUM_MIN; i <= LOTTERY_NUM_MAX; i++) {
            lotteryNumbers.put(i, new LotteryNumber(i));
        }
    }

    private LotteryNumber(int number) {
        this.lotteryNumber = number;
    }

    // 정적 팩토리 메서드
    public static LotteryNumber lotteryNumber(int number) {
        // 미리 생성해둔 인스턴스 중에 찾아서 반환
        LotteryNumber lotteryNumber = lotteryNumbers.get(number);

        validate(lotteryNumber);
        return lotteryNumber;
    }

    private static void validate(LotteryNumber lotteryNumber) {
        if (lotteryNumber == null) {
            throw new IllegalArgumentException("로또 번호는 1과 45 사이의 정수여야 합니다.");
        }
    }
  
  // Object, Comparable 오버라이드 메서드 생략
}
```

3.   정해진 반환 타입의 하위 타입도 반환이 가능해진다.
4.   입력 매개변수에 따라 매번 다른 클래스의 객체를 반환할 수 있다.

정확하게 동일한 타입만 반환 가능한 생성자와 달리 정적 팩토리 메서드를 사용하면 **반환 타입의 하위 타입**도 반환이 가능해진다. 이러한 특징은 구현 클래스를 공개하지 않고도 해당 객체를 반환할 수 있게 하여 API를 작게 유지할 수 있게 해준다. 예를 들어 아래 자바 API의 EnumSet은 아래와 같이 noneOf() 라는 정적 팩토리 메서드를 제공한다.

```java
public static <E extends Enum<E>> EnumSet<E> noneOf(Class<E> elementType) {
    Enum<?>[] universe = getUniverse(elementType);
    if (universe == null)
        throw new ClassCastException(elementType + " not an enum");

    if (universe.length <= 64)
        return new RegularEnumSet<>(elementType, universe);
    else
        return new JumboEnumSet<>(elementType, universe);
}
```

위에서 말한 특징 덕분에 EnumSet이 내부적으로 원소의 개수에 따라 RegularEnumSet 혹은 JumboEnumSet 라는 구현 클래스를 사용함에도 불구하고 반환 타입은 EnumSet으로 동일하게 가져갈 수 있다. 이를 받는 클라이언트 또한 (명시한 인터페이스대로 동작하는 객체를 얻을 것임을 알기에) 별도 문서를 찾아가며 구현 클래스가 무엇인지 찾아보지 않고 동일하게 해당 객체를 사용할 수 있게 된다.

또한 API를 공개한 이후 새로운 구현 클래스가 추가되거나 제거되어도 위와 같은 구조로 API를 설계했다면 클라이언트에게 알리지 않고 구현 클래스를 나중에 추가 / 삭제한다고 하더라도 전혀 문제가 되지 않는다. 클라이언트는 구현 클래스가 어떤 것인지 알 필요없지 단지 EnumSet의 하위 클래스이고 EnumSet의 규약(인터페이스)대로 해당 클래스가 동작하기만 하면 되기 때문이다. 정적 팩토리 메서드는 다형성을 이용해 이러한 유연성을 제공한다.

5.   정적 팩토리 메서드를 작성하는 시점에는 반환할 객체의 클래스가 존재하지 않아도 된다.

3번, 4번 장점과 통하는 부분이 있는 장점이라고 생각한다. 책에서는 이러한 유연함을 통해 **서비스 제공자 프레임워크**를 만들 수 있다고 말한다. **서비스 제공자 프레임워크**란 JDBC, JPA 와 같이 클라이언트에서 서비스의 구현체 (제공자)에 접근하는 것을 프레임워크가 통제하여 클라이언트를 특정 구현체로부터 분리해주는 것을 말한다.

서비스 제공자 프레임워크는 1. 서비스 인터페이스 (구현체의 동작 정의), 2. 제공자 등록 API (제공자가 구현체를 등록), 3. 서비스 접근 API (클라이언트가 서비스의 인스턴스를 얻을 때 사용), 4. 서비스 제공자 인터페이스 (인터페이스의 인스턴스를 생성)로 구성되어 있다. JDBC의 경우 각각 1. Connection , 2. DriverManager.registerDriver, 3. DriverManager.getConnection, 4. Driver 가 그 역할을 수행한다.

구현부와 기능부를 분리하고 연결하여 새로운 기능(구현체)을 프레임워크에 추가한다는 관점에서 **브릿지패턴**이 적용되었다고도 볼 수 있는 것 같다.

>   ### 이펙티브 자바 [전체 아이템 목록](https://github.com/2023-java-study/book-study/tree/main/%EC%9D%B4%ED%8E%99%ED%8B%B0%EB%B8%8C_%EC%9E%90%EB%B0%94) (스터디 정리 레포지토리)