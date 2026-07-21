package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"cuit-server/pkg/jwxt"
	"golang.org/x/term"
)

func main() {
	if len(os.Args) != 1 && len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "用法: go run ./cmd/jwxt-demo [学年 学期]")
		os.Exit(1)
	}
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("学号: ")
	username, err := reader.ReadString('\n')
	if err != nil {
		fmt.Fprintln(os.Stderr, "登录失败: 读取学号失败")
		os.Exit(1)
	}
	username = strings.TrimSpace(username)

	fmt.Print("密码: ")
	passwordBytes, err := term.ReadPassword(int(os.Stdin.Fd()))
	fmt.Println()
	if err != nil {
		fmt.Fprintln(os.Stderr, "登录失败: 读取密码失败")
		os.Exit(1)
	}
	password := string(passwordBytes)

	client, err := jwxt.NewClient()
	if err != nil {
		fmt.Fprintf(os.Stderr, "登录失败: %s\n", err)
		os.Exit(1)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()

	fmt.Println("正在登录...")
	if err := client.Login(ctx, username, password); err != nil {
		fmt.Fprintf(os.Stderr, "登录失败: %s\n", err)
		os.Exit(1)
	}

	fmt.Println("登录成功")
	if len(os.Args) == 3 {
		if err := printGrades(ctx, client, os.Args[1], os.Args[2]); err != nil {
			fmt.Fprintf(os.Stderr, "成绩查询失败: %s\n", err)
			os.Exit(1)
		}
	}
}

func printGrades(ctx context.Context, client *jwxt.Client, schoolYear string, term string) error {
	semesters, err := client.ListSemesters(ctx)
	if err != nil {
		return err
	}
	for _, semester := range semesters {
		if semester.SchoolYear != schoolYear || semester.Term != term {
			continue
		}
		grades, err := client.GetGrades(ctx, semester.ID)
		if err != nil {
			return err
		}
		encoder := json.NewEncoder(os.Stdout)
		encoder.SetIndent("", "  ")
		return encoder.Encode(grades)
	}
	return fmt.Errorf("未找到学期 %s 第%s学期", schoolYear, term)
}
