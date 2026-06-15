extends Node

signal hex_clicked(hex_data: Dictionary)
signal hex_hovered(hex_data: Dictionary)
signal hex_unhovered()
signal camera_moved(position: Vector2, zoom: float)
signal game_tick(tick_number: int)
signal grid_status(cells: int, provinces: int, nations: int)
