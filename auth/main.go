package main

import (
	_ "embed"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

//go:embed login.html
var loginPage []byte

var (
	user      = os.Getenv("LOGIN_USER")
	pass      = os.Getenv("LOGIN_PASS")
	secretKey = []byte(os.Getenv("JWT_SECRET"))
)

func issueToken(c *gin.Context) {
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": user,
		"exp": time.Now().Add(24 * time.Hour).Unix(),
	})
	s, _ := t.SignedString(secretKey)
	// Secure & HttpOnly: le cookie n'est accessible ni en HTTP non-TLS ni en JS
	c.SetCookie("token", s, 86400, "/", "", true, true)
}

func tokenValid(c *gin.Context) bool {
	t, err := c.Cookie("token")
	if err != nil {
		return false
	}
	_, err = jwt.Parse(t, func(tok *jwt.Token) (interface{}, error) { return secretKey, nil })
	return err == nil
}

func main() {
	if user == "" || pass == "" {
		log.Fatal("LOGIN_USER and LOGIN_PASS must be set")
	}

	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	// Page de connexion
	r.GET("/", func(c *gin.Context) {
		c.Data(http.StatusOK, "text/html; charset=utf-8", loginPage)
	})

	// Authentification
	r.POST("/api/login", func(c *gin.Context) {
		if c.PostForm("username") == user && c.PostForm("password") == pass {
			issueToken(c)
			c.Redirect(http.StatusFound, "/labs/") // 302 vers la zone protégée
			return
		}
		c.Redirect(http.StatusFound, "/")          // mauvais identifiants
	})

	// Vérification JWT pour Caddy
	r.GET("/api/verify", func(c *gin.Context) {
		if tokenValid(c) {
			c.Status(http.StatusOK)
		} else {
			c.Status(http.StatusUnauthorized)
		}
	})

	log.Fatal(r.Run(":8081"))
}
