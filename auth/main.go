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
	user         = os.Getenv("LOGIN_USER")
	pass         = os.Getenv("LOGIN_PASS")
	secretKey    = []byte(os.Getenv("JWT_SECRET"))
	cookieDomain = os.Getenv("COOKIE_DOMAIN")
)

// --------------------------------------------------------------------
//  NO-CACHE middleware (empêche la mise en cache côté navigateur)
// --------------------------------------------------------------------
func noCache() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Cache-Control", "no-store, max-age=0")
		c.Writer.Header().Set("Pragma", "no-cache")
		c.Writer.Header().Set("Expires", "0")
		c.Next()
	}
}

// --------------------------------------------------------------------
//  Auth helpers
// --------------------------------------------------------------------
func issueToken(c *gin.Context) {
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": user,
		"exp": time.Now().Add(24 * time.Hour).Unix(),
	})
	signed, _ := t.SignedString(secretKey)

	c.SetSameSite(http.SameSiteLaxMode)
	c.SetCookie("token", signed, 86400, "/", cookieDomain, true, true)
}

func clearToken(c *gin.Context) {
	c.SetSameSite(http.SameSiteLaxMode)
	c.SetCookie("token", "", -1, "/", cookieDomain, true, true)
}

func tokenValid(c *gin.Context) bool {
	t, err := c.Cookie("token")
	if err != nil {
		return false
	}
	_, err = jwt.Parse(t, func(tok *jwt.Token) (interface{}, error) { return secretKey, nil })
	return err == nil
}

// --------------------------------------------------------------------
//  Main
// --------------------------------------------------------------------
func main() {
	if user == "" || pass == "" {
		log.Fatal("LOGIN_USER and LOGIN_PASS must be set")
	}

	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery(), noCache()) // ← middleware anti-cache

	// Page de connexion
	r.GET("/", func(c *gin.Context) {
		c.Data(http.StatusOK, "text/html; charset=utf-8", loginPage)
	})

	// Authentification
	r.POST("/api/login", func(c *gin.Context) {
		if c.PostForm("username") == user && c.PostForm("password") == pass {
			issueToken(c)
			c.Redirect(http.StatusFound, "/labs/") // 302 zone protégée
			return
		}
		c.Redirect(http.StatusFound, "/") // mauvais identifiants
	})

	// Déconnexion
	r.GET("/dc", func(c *gin.Context) {
		clearToken(c)
		c.Header("Clear-Site-Data", "\"cookies\"")
		c.Redirect(http.StatusFound, "/")
	})

	// Vérification JWT pour Caddy (forward_auth)
	r.GET("/api/verify", func(c *gin.Context) {
		if tokenValid(c) {
			c.Status(http.StatusOK) // Auth OK
			return
		}
		c.Status(http.StatusUnauthorized) // Auth KO
	})

	log.Fatal(r.Run(":8081"))
}
