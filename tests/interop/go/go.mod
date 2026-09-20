module reqbest-interop-servers

go 1.25.0

require (
	github.com/quic-go/quic-go v0.55.0
	golang.org/x/net v0.52.0
)

require (
	github.com/quic-go/qpack v0.5.1 // indirect
	golang.org/x/crypto v0.49.0 // indirect
	golang.org/x/mod v0.33.0 // indirect
	golang.org/x/sync v0.20.0 // indirect
	golang.org/x/sys v0.42.0 // indirect
	golang.org/x/text v0.35.0 // indirect
	golang.org/x/tools v0.42.0 // indirect
)

replace golang.org/x/crypto => golang.org/x/crypto v0.43.0

replace golang.org/x/mod => golang.org/x/mod v0.29.0

replace golang.org/x/net => golang.org/x/net v0.52.0

replace golang.org/x/sync => golang.org/x/sync v0.21.0

replace golang.org/x/sys => golang.org/x/sys v0.41.0

replace golang.org/x/text => golang.org/x/text v0.35.0

replace golang.org/x/tools => golang.org/x/tools v0.38.0

replace github.com/google/go-cmp => github.com/google/go-cmp v0.7.0

replace github.com/stretchr/testify => github.com/stretchr/testify v1.11.1

replace go.uber.org/mock => go.uber.org/mock v0.6.0
