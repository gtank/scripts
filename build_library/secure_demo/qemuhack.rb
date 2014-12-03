#!/usr/bin/env ruby

cert = OpenSSL::X509::Certificate.new(File.read("Boot-CA.crt"))
key = OpenSSL::PKey::RSA.new(File.read("Boot-CA.key"))
cert.not_before = Time.at(0)
newCert = cert.sign(key, OpenSSL::Digest::SHA256.new)
File.write("Boot-CA.crt", newCert)
