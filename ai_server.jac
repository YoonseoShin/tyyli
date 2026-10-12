"""Standalone API entry point for clothing-image analysis.

Run this separately from the mobile Metro process so the simulator always has
an HTTP server available for the generated Jac RPC call.
"""
import from .clothing_ai { analyze_clothing_image }
