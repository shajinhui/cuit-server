package login

import "testing"

func TestIsLoginPageDoesNotUseBroadTextMatch(t *testing.T) {
	page := &Page{
		URL: mustTestURL(t, "http://jwgl.cuit.edu.cn/eams/home.action"),
		Body: []byte(`
<html><body>
  <a href="/eams/logout.action">退出登录</a>
  <script>var returnTo = "authserver/login";</script>
</body></html>`),
	}

	if isLoginPage(page) {
		t.Fatal("normal EAMS page with login-like text should not be classified as login page")
	}
}
