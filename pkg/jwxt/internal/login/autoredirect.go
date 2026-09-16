package login

import (
	"net/url"
	"regexp"
	"strings"
)

const (
	// autoRedirectLimit 限制脚本跳转的跟随次数。学校 CAS 链路上有两类“非 HTTP 跳转”：
	// 登录入口桥接页的 <a id="jump">，以及票据消费页里的 window.location.href。
	// 正常链路只有两跳，超过上限说明页面互相指向，直接停止而不是继续请求。
	autoRedirectLimit = 5
	// autoRedirectMaxBody 只对体积极小的桥接页解析脚本跳转，避免在业务页面里把普通
	// JavaScript 误当成跳转指令。
	autoRedirectMaxBody = 4096
)

var (
	scriptAssignPattern  = regexp.MustCompile(`(?i)(?:window\.)?location(?:\.href|\.assign)?\s*=\s*['"]([^'"]+)['"]`)
	scriptReplacePattern = regexp.MustCompile(`(?i)location\.replace\s*\(\s*['"]([^'"]+)['"]`)
)

// parseAutoRedirect 解析页面里的“非 HTTP 跳转”。学校的 CAS 桥接页（含 <a id="jump">
// 或 window.location.href）用 HTTP 200 返回 HTML，跳转只发生在浏览器执行脚本之后；
// 只跟随 HTTP 3xx 会在这些中间页停下，导致会话始终没有建立。
func parseAutoRedirect(from *url.URL, body []byte) (*url.URL, bool) {
	if from == nil || len(body) == 0 || len(body) > autoRedirectMaxBody {
		return nil, false
	}
	if jump, err := parsePortalBridgeRedirect(from, body); err == nil && isFollowableRedirect(from, jump) {
		return jump, true
	}
	target := parseScriptRedirect(body)
	if target == "" {
		return nil, false
	}
	next, err := from.Parse(target)
	if err != nil || !isFollowableRedirect(from, next) {
		return nil, false
	}
	return next, true
}

func parseScriptRedirect(body []byte) string {
	text := string(body)
	if match := scriptAssignPattern.FindStringSubmatch(text); len(match) > 1 {
		return strings.TrimSpace(match[1])
	}
	if match := scriptReplacePattern.FindStringSubmatch(text); len(match) > 1 {
		return strings.TrimSpace(match[1])
	}
	return ""
}

// isFollowableRedirect 只允许跟随 http(s) 且同一主机或学校域名下的地址，防止上游页面
// 把已经建立一半的会话引导到外部站点。
func isFollowableRedirect(from *url.URL, to *url.URL) bool {
	if to == nil || to.Host == "" {
		return false
	}
	if to.Scheme != "http" && to.Scheme != "https" {
		return false
	}
	if from != nil && strings.EqualFold(hostname(from), hostname(to)) {
		return true
	}
	host := strings.ToLower(hostname(to))
	return host == "cuit.edu.cn" || strings.HasSuffix(host, ".cuit.edu.cn")
}

func sameURL(left *url.URL, right *url.URL) bool {
	if left == nil || right == nil {
		return false
	}
	return left.String() == right.String()
}
