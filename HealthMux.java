import java.io.InputStream;
import java.io.OutputStream;
import java.net.ServerSocket;
import java.net.Socket;

// TCP front for the device-ingest port (Railway injects PORT = the TCP proxy's
// application port). Railway's HTTP healthcheck probes <port>/api/health on this
// same port, so requests for /api/health are forwarded to the Traccar web server
// (real DB-aware health) while every other byte stream is piped to the OsmAnd
// protocol listener. Both targets run on localhost inside the same container.
public class HealthMux {

    public static void main(String[] args) throws Exception {
        int port = Integer.parseInt(env("PORT", "5055"));
        int osmand = Integer.parseInt(env("OSMAND_PORT", "5056"));
        int web = Integer.parseInt(env("WEB_PORT", "8082"));
        ServerSocket ss = new ServerSocket(port);
        System.out.println("[railway] HealthMux listening on " + port
                + " (api/health -> " + web + ", devices -> " + osmand + ")");
        while (true) {
            Socket client = ss.accept();
            Thread t = new Thread(() -> handle(client, osmand, web));
            t.setDaemon(true);
            t.start();
        }
    }

    static void handle(Socket client, int osmand, int web) {
        byte[] head = new byte[16 * 1024];
        int headLen = 0;
        try {
            client.setSoTimeout(8000);
            InputStream in = client.getInputStream();
            // read until end of HTTP header block (or cap) to see the request line
            while (headLen < head.length) {
                int b = in.read();
                if (b < 0) break;
                head[headLen++] = (byte) b;
                if (headLen >= 4 && new String(head, headLen - 4, 4).equals("\r\n\r\n")) break;
            }
            String firstLine = new String(head, 0, Math.min(headLen, 256));
            int target = firstLine.startsWith("GET /api/health") ? web : osmand;
            System.out.println("[railway] HealthMux " + firstLine.split("\r\n")[0] + " -> " + target);
            Socket upstream = new Socket("127.0.0.1", target);
            OutputStream cout = client.getOutputStream();
            InputStream uin = upstream.getInputStream();
            OutputStream uout = upstream.getOutputStream();
            Thread a = new Thread(() -> pipe(in, uout));
            Thread b = new Thread(() -> pipe(uin, cout));
            uout.write(head, 0, headLen);
            uout.flush();
            a.setDaemon(true);
            b.setDaemon(true);
            a.start();
            b.start();
            a.join(300000);
            b.join(300000);
        } catch (Exception e) {
            System.out.println("[railway] HealthMux connection error: " + e);
        } finally {
            try { client.close(); } catch (Exception ignored) { }
        }
    }

    static void pipe(InputStream in, OutputStream out) {
        byte[] buf = new byte[8192];
        try {
            int n;
            while ((n = in.read(buf)) >= 0) {
                out.write(buf, 0, n);
                out.flush();
            }
        } catch (Exception ignored) {
        } finally {
            try { out.close(); } catch (Exception ignored) { }
        }
    }

    static String env(String key, String fallback) {
        String v = System.getenv(key);
        return (v == null || v.isEmpty()) ? fallback : v;
    }
}
