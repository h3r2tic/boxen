module xf.mem.Common;



const size_t	defaultAllocationAlignment = 16;
const size_t	minDefaultPageSize = 64 * 1024;//4096;


void* alignPointerUp(void* ptr, size_t boundary) {
	return cast(void*)(((cast(size_t)ptr + boundary - 1) / boundary) * boundary);
}
