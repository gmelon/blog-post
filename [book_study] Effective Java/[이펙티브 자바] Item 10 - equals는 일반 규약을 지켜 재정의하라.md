아이템 10번은 equals를 재정의할 때 지켜야 할 규칙들과 주의해야 하는 점들에 대해 설명하고 있다. 자바에서 equals()를 재정의하지 않으면 오직 자기 자신의 인스턴스와만 같게 되기 때문에 필요한 경우 equals() 메서드를 재정의해서 사용해야 한다.

>    책에서는 equals가 만족해야 하는 규칙들 모두에 대해 상황을 제시해 예제 코드로 설명하고 있지만 이를 모두 정리할 필요는 없을 것 같아 중요한 내용만 옮겼으니 자세한 내용은 책을 참고하시길 바랍니다.

## equals가 필요 없는 상황

equals() 를 재정의해서 불필요한 문제가 발생할 수도 있으므로 아래의 경우에 해당된다면 equals()를 아예 재정의하지 않는 것도 좋은 방법이다. 이 경우 기본 `Object.equals()` 가 호출되어 (**주소 값 비교**) 오직 자기 자신의 인스턴스와만 같다는 결과가 나오게 된다.

*   각 인스턴스가 **본질적으로** 고유 (쓰레드 등)
*   설계 상 **동등성**을 검사할 필요가 없는 경우
*   상위 클래스 (주로 abstract) 의 equals()가 하위 클래스에도 딱 들어맞는 경우
    *   자바 API의 경우 `AbstractList -> List`, `AbstractMap -> Map구현체들` 이 이렇게 구현되어 있다.

## equals가 필요한 상황

`객체 식별성` (두 객체가 `물리적`으로  같은가, `동일성`) 이 아니라 `논리적 동치성 (동등성)`을 확인해야 하는데 상위 클래스의 equals() 가 이를 확인하도록 재정의되어 있지 않을 때는 필수로 equals()를 재정의해야 한다. 주로 Integer, String과 같은 `값 클래스` 들이 여기에 해당한다.

값 클래스의 경우 주소가 a이고 값이 1인 객체와 주소가 b이고 값이 1인 객체는 동일한 객체로 판단되어야 하므로 equals() 구현이 필요한 상황이라고 할 수 있다.

값 클래스가 아니고 불변이 아니더라도 주소가 아닌 현재 객체의 상태에 따라 동등성을 확인하고자 하는 클래스라면 equals()를 재정의하고 핵심 필드의 값을 비교하도록 구현해야 한다.

### equals가 만족해야 하는 규칙들

equals()는 아래의 일반 규약을 지켜 재정의되어야 한다. `자바 컬렉션을 포함한 다른 수많은 클래스들은 equals()가 아래 규약을 지켰다고 가정하고 동작`하므로 이를 지키는 것은 매우 중요하며, 지키지 않을 경우 개발자의 의도와 다르게 프로그램이 동작할 수 있다. 

예를 들어 equals()를 구현하지 않은 값 클래스를 List에 넣고 동일한 값을 같는 새로운 인스턴스를 만들고 인자로 넘겨서 List.contains()를 호출하면 false가 나오게 된다. 반면, equals()를 제대로 구현하면 true가 나온다.

```java
MyClass myClassA = new MyClass(3);

List<MyClass> myClasses = new ArrayList<>();
myClasses.add(myClassA);

/**
 * equals() 구현 X -> false
 * equals() 구현 O -> true
 */
myClasses.contains(new MyClass(3));
```

아래에서 x, y, z는 각각 `null이 아닌 참조 값`이다.

*   반사성
    *   모든 x에 대해, x.equals(x) 는 true
*   대칭성
    *   모든 x, y에 대해, x.equals(y)가 true면 y.equals(x)도 true
*   추이성
    *   모든 x, y, z에 대해 x.equals(y)가 true고 y.equals(z)도 true면 x.equals(z)도 true
*   일관성
    *   x.equals(y)를 반복 호출해도 계속 같은 결과가 나와야 힘
*   null-아님
    *   모든 x에 대해 x.equals(null)은 false

### 상속 관계에서의 equals

부모 클래스가 있고, 이를 상속받는 하위 클래스에서 새로운 필드를 가질 때 이 두 클래스에 대한 equals() 재정의는 굉장히 까다롭다. 책에서 아주 자세히 설명하고 있다.

예를 들어 Point와 이를 상속받는 ColorPoint가 있다고 할 때 하위 클래스는 항상 부모 클래스로 대체되어 사용가능해야 하므로 (리스코프 치환 원칙, LSP) 아래와 같이 사용이 가능하고 각 클래스의 equals()도 이를 고려하여 설계되어야 한다.

```java
class Point {
    private int x, y;
    // 생성자 등
}

class ColorPoint extends Point {
    private String color;
    // 생성자 등
}

Point point = new Point(1, 1);
Point colorPoint = new ColorPoint(1, 1, "red");

point.equals(colorPoint); // true가 되어야 함
colorPoint.equals(point); // true가 되어야 함
```

이를 위해 아래와 같이 Point와 ColorPoint의 equals()를 구현했다고 해보자.

#### Point

```java
@Override
public boolean equals(Object o) {
    if (!(o instanceof Point)) {
        return false;
    }
    Point p = (Point) o; // 항상 성공
    return p.x == x && p.y == y;
}
```

#### ColorPoint

```java
@Override
public boolean equals(Object o) {
    if (!(o instanceof Point)) {
        return false;
    }
    
    if (!(o instanceof ColorPoint)) {
        // 주어진 o가 Point면 Point의 equals()로 비교
        return o.equals(this);
    }
    
    // 주어진 o가 ColorPoint면 색상까지 비교
    ColorPoint c = (ColorPoint) o;
    return super.equals(o) && c.color.equals(color);
}
```

언뜻 보기에는 문제 없이 작동할 것 같지만, 아래와 같은 경우에 추이성이 깨지는 문제가 발생한다.

```java
ColorPoint obj1 = new ColorPoint(1, 2, "red");
Point obj2 = new Point(1, 2);
ColorPoint obj3 = new ColorPoint(1, 2, "green");
```

equals()의 일반 규약 중 추이성에 따르면 obj1.equals(obj2) 가 true 이고 obj2.equals(obj3) 가 true 이므로 obj1.equals(obj3) 도 true 여야 한다. 하지만 마지막 equals() 문은 false를 반환한다. ColorPoint 끼리의 비교는 `color` 필드까지도 비교하기 때문이다.

책에서는 이 밖에도 다양한 경우의 (문제 있는) 예제 코드를 제시하며 상속 관계에서 하위 클래스가 필드를 추가한다면 정상적으로 equals 규약을 만족시킬 방법이 없다고 이야기한다. 그리고 그에 대한 해결책으로 `상속 대신 컴포지션을 사용`하라고 말한다.

컴포지션을 사용해 ColorPoint를 아래와 같이 구현한다면, ColorPoint의 equals() 에서 현재 인스턴스가 Point 인지 여부를 확인해줄 필요가 없기 때문에 앞서 이야기한 문제들이 전혀 발생하지 않는다.

```java
// 컴포지션을 사용한 ColorPoint
public final class ColorPoint {
    private Point point;
    private String color;
    
    public ColorPoint(int x, int y, String color) {
        this.point = new Point(x, y);
        this.color = color;
    }
    
    // Point 뷰를 반환하는 메서드를 제공하여
    // ColorPoint가 Point로서 활용될 수 있도록 함
    public Point asPoint() {
        return point;
    }
    
    @Override
    public boolean equals(Object o) {
        // ColorPoint가 아니면 무조건 false를 반환할 수 있게 된다.
        if (!(o instanceof ColorPoint)) {
            return false;
        }
        ColorPoint c = (ColorPoint) o;
        return c.point.equals(this.point) && c.color.equals(this.color);
    }
}
```

ColorPoint의 equals() 메서드에 무조건 ColorPoint만 인자로 전달되므로 위와 같이 equals() 메서드를 작성할 수 있게 되었다.  `asPoint()` 와 같은 메서드를 제공해 ColorPoint가 Point로 활용되어야할 경우도 대응할 수 있다.

>   비슷한 이유로 `상위 클래스가 추상 클래스`인 경우에도 해당 클래스가 인스턴스화 될 수 없으므로 equals() 구현 시 문제가 발생하지 않는다.

## equals 구현 시 주의점

1.   equals() 비교에 신뢰할 수 없는 자원 사용하지 않기
     1.   ex) url 대신 이에 매핑되는 ip주소로 equals() 수행
2.   null도 정상 값으로 취급하는 객체는 `Objects.equals()`로 비교하기
     1.   Objects.equals()는 아래와 같이 구현되어 있어 호출 대상 객체가 null인 경우도 대응할 수 있다.

```java
public static boolean equals(Object a, Object b) {
    return (a == b) || (a != null && a.equals(b));
}
```

3.   다를 가능성이 크거나 비교 비용이 저렴한 필드부터 비교하기
     1.   해당 필드의 값이 다를 경우 이후 필드를 계산하지 않고 바로 false를 반환할 수 있다
4.   hashcode도 반드시 재정의하기 (Item 11)
     1.   hashcode가 재정의되어 있지 않을 경우 hash를 사용하는 컬렉션의 성능이 저하될 수 있다.
5.   equals()의 인자는 반드시 Object여야 한다
     1.   예를 들어 아래와 같이 하게 되면 재정의가 아닌 다중정의가 되므로 반드시 Object로 해야 한다

```java
public boolean equals(MyClass o) {
    // 금지
}
```

6.   IDE가 만들어주는 equals()를 애용하자!
     1.   다만, 필드가 추가되는 경우 등에 대비해 (자동 갱신 되지 않으므로) 테스트 코드를 항상 작성해두가
     2.   비교하지 않아도 되는 필드(혹은 하지 말아야 하는)는 제외한다

>    이펙티브 자바 [전체 아이템 목록](https://github.com/2023-java-study/book-study/tree/main/%EC%9D%B4%ED%8E%99%ED%8B%B0%EB%B8%8C_%EC%9E%90%EB%B0%94) (스터디 정리 레포지토리)