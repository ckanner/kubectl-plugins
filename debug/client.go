package main

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"sync"
    "strings"
)

var containerId = flag.String("container_id", "", "container id")
var cmd = flag.String("cmd", "/bin/sh", "debug cmd")
var nodeIp = flag.String("node_ip", "", "node ip")

func main() {
	flag.Parse()
	address := fmt.Sprintf("%s:9098", *nodeIp)
	conn, err := net.Dial("tcp", address)
	if err != nil {
		log.Fatalf("connect to server %s fail: %s ", address, err)
	}
	defer conn.Close()
	handleConn(conn)
}

func handleConn(conn net.Conn) {
    // write a line: containerId,cmd
    notifyReq := fmt.Sprintf("%s,%s", *containerId, *cmd)
    _, err := conn.Write([]byte(notifyReq))
    if err != nil {
        log.Printf("notify server fail: %s", err)
        return
    }
    // read a line: ok
    reader := bufio.NewReader(conn)
    notifyResp, err := reader.ReadString('\n')
    if err != nil || strings.ToLower(notifyResp) != "ok" {
        log.Printf("notify server to create container fail: %s", err)
        return
    }
    closeCh := make(chan struct{})
    var wg sync.WaitGroup
    wg.Add(2)
    go handleWrite(conn, &wg, closeCh)
    go handleRead(conn, &wg, closeCh)
	wg.Wait()
}

func handleWrite(conn net.Conn, wg *sync.WaitGroup, closeCh chan struct{})  {
    defer wg.Done()
    // start
    go handleRead(conn, wg, closeCh)
    stdin := bufio.NewReader(os.Stdin)
    for {
        select {
        case <-closeCh:
            break
        default:
        }
        // read from stdin
        input, _ := stdin.ReadString('\n')
        conn.Write([]byte(input + "\n"))
    }
}

func handleRead(conn net.Conn, wg *sync.WaitGroup, closeCh chan struct{}) {
	defer wg.Done()
	var data [1024]byte
	for {
		n, err := conn.Read(data[:])
		if err == io.EOF {
			closeCh <- struct{}{}
			break
		}
		if err != nil {
			log.Printf("read from conn fail: %s", err)
			continue
		}
		os.Stdout.Write(data[:n])
	}
}
