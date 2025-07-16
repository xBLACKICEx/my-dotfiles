alias dk = docker

# List images
def dils [] {
    docker image ls --format "{{.Repository}}|{{.ID}}|{{.Tag}}|{{.CreatedAt}}|{{.Size}}" 
    | lines 
    | split column "|" Repository 'Image ID' Tag 'Created At' Size
    | update 'Created At' { |row| $row."Created At" | into datetime }
}

# docker inspect
def dispt [container_id] {
    docker inspect $container_id | from json | get 0
}

# docker ps
def --wrapped dps [...rest] {
    docker ps ...$rest --format "{{.ID}}|{{.Image}}|{{.Command}}|{{.CreatedAt}}|{{.Ports}}|{{.Status}}|{{.Size}}|{{.Names}}" 
    | lines 
    | split column "|" ID Image Command 'Created At' Ports Status Size Names
    | update 'Created At' { |row| $row."Created At" | into datetime }
}

# docker stats
def --wrapped dstats [...rest] {
        docker stats --no-stream --format "{{.Container}}|{{.CPUPerc}}|{{.MemUsage}}|{{.NetIO}}|{{.BlockIO}}|{{.PIDs}}" 
            | lines
            | split column "|" Container CPU Memory 'Network IO' 'Block IO' PIDs
            | update CPU { |row| $row.CPU | str replace "%" "" | into float }
            | sort-by CPU -r
            | table
}


alias dimges = dk images

