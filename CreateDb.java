import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;

// Boot helper: waits for MySQL to accept connections and ensures the traccar
// database exists. Uses the same JDBC driver Traccar runs with, so this proves
// the exact credentials/URL the app will use. Retries for up to 5 minutes.
public class CreateDb {
    public static void main(String[] args) throws Exception {
        String host = env("DB_HOST", "mysql.railway.internal");
        String user = env("DATABASE_USER", "root");
        String pass = env("DATABASE_PASSWORD", "");
        String url = "jdbc:mysql://" + host + ":3306/"
                + "?allowPublicKeyRetrieval=true&useSSL=false&serverTimezone=UTC"
                + "&connectTimeout=5000&socketTimeout=30000";
        int i = 0;
        while (true) {
            try (Connection c = DriverManager.getConnection(url, user, pass);
                 Statement s = c.createStatement()) {
                s.execute("CREATE DATABASE IF NOT EXISTS traccar CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
                System.out.println("[railway] MySQL ready; database 'traccar' ensured");
                return;
            } catch (SQLException e) {
                i++;
                if (i == 1 || i % 6 == 0) {
                    System.out.println("[railway] waiting for MySQL (attempt " + i + "): " + e.getMessage());
                }
                if (i >= 60) {
                    System.out.println("[railway] MySQL not reachable after 5 minutes - giving up (Railway will restart)");
                    System.exit(1);
                }
                Thread.sleep(5000);
            }
        }
    }

    static String env(String key, String fallback) {
        String v = System.getenv(key);
        return (v == null || v.isEmpty()) ? fallback : v;
    }
}
