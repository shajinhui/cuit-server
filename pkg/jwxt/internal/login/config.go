package login

import (
	"io"
	"net/url"
)

type Config struct {
	EAMSBaseURL   *url.URL
	VerifyURL     *url.URL
	PortalBaseURL *url.URL
	MaxRedirects  int
	Output        io.Writer
	// TraceLogin 打开后会把单点登录的关键步骤写入 Output。
	// 业务系统（如图书馆）的登录链路与教务不同，出问题时需要这些步骤定位。
	TraceLogin bool
}
