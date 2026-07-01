package main

import "github.com/ryangerardwilson/carbide/internal/carbide"

var commit string

func main() {
	carbide.SetCommit(commit)
	carbide.Main()
}
