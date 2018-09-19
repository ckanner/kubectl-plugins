package main

import (
    "net"
    "bufio"
    "strings"
    "log"
    "github.com/docker/docker/client"
    "context"
    "github.com/docker/docker/api/types"
    "github.com/docker/docker/api/types/container"
    "io"
    "sync"
)

const DebugImage = "ubuntu:16.04"

func handleConn(conn net.Conn)  {
    defer conn.Close()
    // read a line: containerId,cmd
    reader := bufio.NewReader(conn)
    notifyReq, err := reader.ReadString('\n')
    if err != nil {
        log.Printf("read notify req fail: %s", err)
        return
    }
    arr := strings.Split(notifyReq, ",")
    if len(arr) != 2 {
        log.Printf("parse notify req fail: %s", err)
        return
    }
    containerId := arr[0]
    cmd := arr[1]

    cli, err := client.NewClientWithOpts(client.WithVersion("1.38"))
    if err != nil {
        log.Printf("connect to docker fail: %s", err)
        return
    }
    defer cli.Close()
    debugContainerId, debugContainerConn, err := createDebugContainer(cli, containerId, cmd)
    if err != nil {
        // send fail resp
        conn.Write([]byte("Fail\n"))
        log.Printf("create debug container fail: %s", err)
        return
    }
    defer cli.ContainerRemove(context.Background(), debugContainerId, types.ContainerRemoveOptions{RemoveLinks:true, RemoveVolumes:true, Force:true})
    closeCh := make(chan struct{})
    var wg sync.WaitGroup
    wg.Add(2)
    go handleWrite(conn, debugContainerConn, &wg, closeCh)
    go handleRead(conn, debugContainerConn, &wg, closeCh)
    wg.Wait()

}

func handleWrite(conn net.Conn, debugContainerConn net.Conn, wg *sync.WaitGroup, closeCh chan struct{})  {
    defer wg.Done()
    var data [1024]byte
    for {
        n, err := debugContainerConn.Read(data[:])
        if err == io.EOF {
            conn.Close()
            break
        }
        if err != nil {
            log.Printf("read from debug container fail: %s", err)
            continue
        }
        select {
        case <- closeCh:
            break
        default:

        }
        conn.Write(data[:n])
    }
}

func handleRead(conn net.Conn, debugContainerConn net.Conn, wg *sync.WaitGroup, closeCh chan struct{})  {
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
        debugContainerConn.Write(data[:n])
    }
}

func createDebugContainer(cli client.APIClient, containerId, cmd string) (string, net.Conn, error) {
    ctx := context.Background()
    _, err := cli.ImagePull(ctx, DebugImage, types.ImagePullOptions{})
    if err != nil {
        return "", nil, err
    }
    resp, err := cli.ContainerCreate(ctx, &container.Config{
        Image:     DebugImage,
        Cmd:       []string{cmd},
        OpenStdin: true,
        Tty:       true,
    }, &container.HostConfig{
        NetworkMode: container.NetworkMode("container:" + containerId),
        PidMode: container.PidMode("container:" + containerId),
        IpcMode: container.IpcMode("container:" + containerId),
    }, nil, "")
    if err != nil {
        return "", nil, err
    }
    if err := cli.ContainerStart(ctx, resp.ID, types.ContainerStartOptions{}); err != nil {
        return "", nil, err
    }
    hijackedResp, err := cli.ContainerAttach(ctx, resp.ID, types.ContainerAttachOptions{Stdin: true, Stdout: true, Stream: true})
    if err != nil {
        return "", nil, err
    }
    return resp.ID, hijackedResp.Conn, nil
}

func main() {
    address := "0.0.0.0:8086"
    listener, err := net.Listen("tcp4", address)
    if err != nil {
        log.Fatalf("listen on %s fail, %s", address, err)
    }
    defer listener.Close()
    for {
        conn, err := listener.Accept()
        if err != nil {
            log.Println("accept connection fail, ", err)
            
        }
        go handleConn(conn)
    }
}
