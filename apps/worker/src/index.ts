const EAMS_URL = "http://jwgl.cuit.edu.cn/eams/";
const CAS_URL = "https://sso.cuit.edu.cn/authserver/login";
const REQUEST_TIMEOUT_MS = 15_000;

type EndpointResult = {
  reachable: boolean;
  host: string;
  path: string;
  status?: number;
  location?: {
    host: string;
    path: string;
  };
  error?: string;
};

type ProbeResult = {
  ok: boolean;
  eams: EndpointResult;
  cas: EndpointResult;
};

async function probe(url: URL): Promise<EndpointResult> {
  const result: EndpointResult = {
    reachable: false,
    host: url.host,
    path: url.pathname,
  };

  try {
    const response = await fetch(url, {
      headers: {
        Accept: "text/html,application/xhtml+xml",
        "User-Agent":
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " +
          "(KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36",
      },
      redirect: "manual",
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });

    result.reachable = true;
    result.status = response.status;

    const location = response.headers.get("Location");
    if (location) {
      const redirectURL = new URL(location, url);
      result.location = {
        host: redirectURL.host,
        path: redirectURL.pathname,
      };
    }

    await response.body?.cancel();
    return result;
  } catch {
    result.error = "network request failed or timed out";
    return result;
  }
}

async function probeLoginEndpoints(): Promise<ProbeResult> {
  // 独立探测两个入口，避免 EAMS 不可达时掩盖 CAS 自身的连通性。
  const [eams, cas] = await Promise.all([
    probe(new URL(EAMS_URL)),
    probe(new URL(CAS_URL)),
  ]);

  return {
    ok: eams.reachable && cas.reachable,
    eams,
    cas,
  };
}

function json(body: ProbeResult | { error: string }, status: number): Response {
  return Response.json(body, {
    status,
    headers: {
      "Cache-Control": "no-store",
    },
  });
}

export default {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (request.method !== "GET" || url.pathname !== "/") {
      return json({ error: "not found" }, 404);
    }

    const result = await probeLoginEndpoints();
    return json(result, result.ok ? 200 : 502);
  },
} satisfies ExportedHandler;
