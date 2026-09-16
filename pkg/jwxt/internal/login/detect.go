package login

import (
	"net"
	"net/url"
	"strings"
)

func isCASLoginURL(u *url.URL) bool {
	if u == nil {
		return false
	}
	// 学校同时部署了 sso.cuit.edu.cn 与一网通办自带的 ywtb.cuit.edu.cn/authserver，
	// 两者的登录页都是同一套 CAS 跳转结构（loginType=cas + redirectUrl），
	// 因此这里按 CAS 登录页处理，后续仍由 Portal 完成账号登录。
	if !strings.Contains(u.Path, "/authserver/login") {
		return false
	}
	return isCASHost(u) || isPortalHost(u)
}

func isLoginPage(page *Page) bool {
	if page == nil {
		return false
	}
	if isCASLoginURL(page.URL) {
		return true
	}
	return (isCASHost(page.URL) || isPortalHost(page.URL)) && hasPortalRoute(page.URL, page.Body)
}

func isCASHost(u *url.URL) bool {
	return strings.EqualFold(hostname(u), "sso.cuit.edu.cn")
}

func isPortalHost(u *url.URL) bool {
	return strings.EqualFold(hostname(u), "ywtb.cuit.edu.cn")
}

func hostname(u *url.URL) string {
	if u == nil {
		return ""
	}
	host := u.Hostname()
	if host != "" {
		return host
	}
	host, _, err := net.SplitHostPort(u.Host)
	if err == nil {
		return host
	}
	return u.Host
}
