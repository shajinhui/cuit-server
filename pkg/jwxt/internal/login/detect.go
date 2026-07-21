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
	return isCASHost(u) && strings.Contains(u.Path, "/authserver/login")
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
