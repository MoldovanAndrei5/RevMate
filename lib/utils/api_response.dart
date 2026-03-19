class ApiResponse<T> {
  T? data;
  int statusCode = 0;

  ApiResponse(this.data, this.statusCode);
}