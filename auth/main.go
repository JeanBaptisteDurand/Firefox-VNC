// main.go — version corrigée (suppression fiable du cookie)

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
// Auth helpers
// --------------------------------------------------------------------

func issueToken(c *gin.Context) {
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": user,
		"exp": time.Now().Add(24 * time.Hour).Unix(),
	})
	signed, _ := t.SignedString(secretKey)

	// Tous les attributs (Path, Domain, SameSite) devront être identiques
	// quand on supprimera le cookie.
	c.SetSameSite(http.SameSiteLaxMode)
	c.SetCookie("token", signed, 86400, "/", cookieDomain, true, true)
}

func clearToken(c *gin.Context) {
	// Reproduire EXACTEMENT les attributs pour écraser le même cookie
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
// Main
// --------------------------------------------------------------------

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
		// Auth KO → réponse 401 pour que Caddy redirige
		c.Status(http.StatusUnauthorized)
	})

	log.Fatal(r.Run(":8081"))
}
