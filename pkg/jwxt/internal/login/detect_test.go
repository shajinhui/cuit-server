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

func TestIsCASLoginURLAcceptsBothSchoolAuthservers(t *testing.T) {
	for _, raw := range []string{
		"https://sso.cuit.edu.cn:443/authserver/login?service=http%3A%2F%2Fjwgl.cuit.edu.cn%2Feams%2F",
		"https://ywtb.cuit.edu.cn/authserver/login?service=http%3A%2F%2Fywtb.cuit.edu.cn%2Fthird_api%2Fyypt%2Fauthcenter%2FdoAuth%2Fabc",
	} {
		if !isCASLoginURL(mustTestURL(t, raw)) {
			t.Fatalf("expected CAS login url: %s", raw)
		}
	}
}

func TestIsCASLoginURLRejectsForeignHosts(t *testing.T) {
	for _, raw := range []string{
		"https://example.com/authserver/login?service=x",
		"https://ywtb.cuit.edu.cn/third_api/yypt/ic-web/auth/address",
		"https://ywtb.cuit.edu.cn/#/login?loginType=cas&redirectUrl=x",
	} {
		if isCASLoginURL(mustTestURL(t, raw)) {
			t.Fatalf("unexpected CAS login url: %s", raw)
		}
	}
}

func TestIsLoginPageAcceptsPortalAuthserverBridge(t *testing.T) {
	page := &Page{
		URL: mustTestURL(t, "https://ywtb.cuit.edu.cn/authserver/login?service=http%3A%2F%2Fywtb.cuit.edu.cn%2Fthird_api%2Fyypt%2Fauthcenter%2FdoAuth%2Fabc"),
		Body: []byte(`<!DOCTYPE html><html><head><title>页面跳转中</title></head><body onload="jump();">
<a id="jump" style="display:none;" href="/#/login?loginType=cas&redirectUrl=http%3A%2F%2Fywtb.cuit.edu.cn%2Fthird_api%2Fyypt%2Fauthcenter%2FdoAuth%2Fabc"></a>
<script type="text/javascript">function jump(){document.getElementById("jump").click();}</script></body></html>`),
	}

	if !isLoginPage(page) {
		t.Fatal("library CAS bridge page should be classified as login page")
	}
}
