"""Standalone API entry point for clothing-image analysis.

Run this separately from the mobile Metro process so the simulator always has
an HTTP server available for the generated Jac RPC call.
"""
import from .clothing_ai { analyze_clothing_image }
import from .outfit_ai { explain_outfit_recommendations }
import from .product_lookup { fetch_product_image, find_product_online, search_product_images }
import from .style_identity { discover_style }
import from .stylist_ai { chat_with_stylist }
