package main

import (
	"archive/tar"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

func Untar(dst string, r io.Reader) error {

	tr := tar.NewReader(r)

	for {
		header, err := tr.Next()

		switch {

		case err == io.EOF:
			return nil
		case err != nil:
			return err

		case header == nil:
			continue
		}

		target := filepath.Join(dst, header.Name)

		switch header.Typeflag {

		case tar.TypeDir:
			if _, err := os.Stat(target); err != nil {
				if err := os.MkdirAll(target, 0755); err != nil {
					return err
				}
			}

		case tar.TypeReg:
			f, err := os.OpenFile(target, os.O_CREATE|os.O_RDWR, os.FileMode(header.Mode))
			if err != nil {
				return err
			}

			if _, err := io.Copy(f, tr); err != nil {
				return err
			}

			f.Close()
		}
	}
}

func InstallBundle(bundlePath string) error {

	reader, err := os.Open(bundlePath)
	if err != nil {
		log.Fatal(err)
	}

	workDir, err := ioutil.TempDir("", "bundle_install")
	if err != nil {
		return err
	}
	defer os.RemoveAll(workDir)

	err = Untar(workDir, reader)
	if err != nil {
		return err
	}

	installScript := filepath.Join(workDir, "install.ps1")

	cmd := exec.Command("powershell", installScript)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Dir = workDir
	err = cmd.Run()

	return err
}

func main() {
	// Get path relative to binary
	baseDir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	if err != nil {
		log.Fatal(err)
	}

	var dirs = [2]string{"bootstrap", "user"}

	for _, pkgDir := range dirs {

		dir := filepath.Join(baseDir, pkgDir)

		files, err := ioutil.ReadDir(dir)
		if err != nil {
			log.Fatal(err)
		}

		for _, file := range files {
			bundle := filepath.Join(dir, file.Name())
			fmt.Println(fmt.Sprintf("Installing: %s", bundle))
			err := InstallBundle(bundle)
			if err != nil {
				log.Fatal(err)
			}
		}

	}

}
