# Changelog - Lenscorrector Professional

## Version 1.1.0 (May 7, 2025)

### Performance Optimizations
- **Buffered Rendering**: Implementation of `OBS_NO_DIRECT_RENDERING` for optimal rendering performance
- **Resource Management**: Improved GPU resource release and memory management
- **Parameter Change Detection**: Shader parameters are only updated when values actually change
- **More Efficient Shader Calculation**: Performance mode uses a simplified algorithm instead of frame-skipping

### Stability & Error Handling
- **Robust Error Handling**: Comprehensive implementation of `pcall` for critical operations
- **Null Checks**: All parameters are checked for `nil` values
- **Improved Initialization**: Default values for all parameters in the `create` function
- **Error Logging**: Detailed debug outputs for easier troubleshooting

### Visual Improvements
- **Adaptive Grid Lines**: Grid line thickness adapts to the image resolution
- **Correct Color Representation**: Color values are now correctly displayed in all screen modes
- **Improved Grid Precision**: More accurate grid display for all grid types
- **Flicker-free Performance Mode**: No more visible artifacts in performance mode

### Additional Improvements
- **UV Coordinate Clamping**: Prevents artifacts at image edges with strong corrections
- **Improved Split-Screen Function**: More reliable display of the comparison image
- **Code Organization**: Better structuring for easier maintenance

## Version 1.0.0 (January 2, 2025)

- Initial release of Lenscorrector Professional
- Support for focal length correction from 8mm to 100mm
- Various grid types: Standard, Perspective, Diagonal, Golden Ratio
- Camera profiles for saving and loading settings
- Multilingual support (German/English)
