# Architecture

One pipelined complex butterfly is reused across six FFT stages. Two 64-entry complex memories operate in ping-pong mode. Input samples are loaded into bit-reversed addresses so final bins are produced in normal order.
