class_name VendorStub
extends Node3D
## v0.5 in-world vendor (SL-style) stub: shows a listing sign; buying via the
## marketplace panel comes with the server. YOUR INPUT HERE: vendor look / what to sell.
func setup() -> void:
	name = "CreatorVendor"
	var K = PropKit
	K.part(self, K.cone(0.9, 1.0, 1.0, 16), K.mat("#0b0910", 0.0, 0.6, 0.2), Vector3(0, 0.5, 0))
	K.part(self, K.sphere(0.6, 16), K.mat("#ff2fd0", 1.5, 0.3, 0.2), Vector3(0, 1.6, 0))
	K.part(self, K.torus(0.7, 0.8), K.mat("#f2bd3a", 0.5, 1.0, 0.2), Vector3(0, 1.6, 0), Vector3.ONE, Vector3(PI / 2, 0, 0))
	K.collider(self, K.cyl_shape(1.0, 1.0), Vector3(0, 0.5, 0))
	var s := PropKit.make_sign("Creator Market (coming soon)", "sell your .glb wearables for Aethel Coin")
	s.position = Vector3(1.6, 0, 0)
	add_child(s)
