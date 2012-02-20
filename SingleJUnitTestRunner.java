import org.junit.runner.*;

public class SingleJUnitTestRunner {
  public static void main(String... args) throws ClassNotFoundException {
    String[] classAndMethod = args[0].split("#");
    Request request = Request.method(Class.forName(classAndMethod[0]), classAndMethod[1]);
    Result result = new JUnitCore().run(request);

    if (result.wasSuccessful()) {
      System.out.println("pass");
    } else {
      System.out.println("fail");
    }

    System.exit(result.wasSuccessful() ? 0 : 1);
  }
}
