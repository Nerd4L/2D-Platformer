using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WaddleDeeAIScript : MonoBehaviour
{
    [SerializeField] private Transform groundCheck;
    [SerializeField] private Transform obstacleCheck;
    [SerializeField] private Transform jumpCheck;
    [SerializeField] private Transform wallCheck;
    [SerializeField] private LayerMask whatIsGround;

    [SerializeField] private bool grounded = false;
    [SerializeField] private bool nearWall = false;
    private bool facingLeft = true;
    [SerializeField] private bool obstacleCanJump = false;

    private Rigidbody2D waddleDeeRB2D;

    [SerializeField] private float jumpForce = 200f;
    [SerializeField] private float moveSpeed = -20f;

    // Start is called before the first frame update
    void Start()
    {
        waddleDeeRB2D = GetComponent<Rigidbody2D>();
    }

    private void FixedUpdate()
    {
        grounded = false;
        nearWall = false;
        obstacleCanJump = false;

        waddleDeeRB2D.velocity = new Vector2(moveSpeed * Time.deltaTime, waddleDeeRB2D.velocity.y);

        // Is it touching the ground
        Collider2D[] groundColliders = Physics2D.OverlapCircleAll(groundCheck.position, 0.1f, whatIsGround);
        for (int l = 0; l < groundColliders.Length; l++)
        {
            if (groundColliders[l].gameObject != gameObject)
            {
                grounded = true;
            }
        }

        // Is it close to a wall
        Collider2D[] obstacleColliders = Physics2D.OverlapCircleAll(obstacleCheck.position, 0.3f, whatIsGround);
        for (int i = 0; i < obstacleColliders.Length; i++)
        {
            if (obstacleColliders[i].gameObject != gameObject)
            {
                nearWall = true;
            }
        }

        // If it's close to a wall, can it jump it
        Collider2D[] jumpColliders = Physics2D.OverlapCircleAll(jumpCheck.position, 0.49f, whatIsGround);
        if (jumpColliders.Length == 0)
        {
            obstacleCanJump = true;
        }

        if (obstacleCanJump && grounded && nearWall)
        {
            Jump();
        }

        // If it touches a wall, turn around
        Collider2D[] wallColliders = Physics2D.OverlapCircleAll(wallCheck.position, 0.11f, whatIsGround);
        for (int k = 0; k < wallColliders.Length; k++)
        {
            if (wallColliders[k].gameObject != gameObject)
            {
                TurnAround();
            }
        }
    }

    private void Jump()
    {
        waddleDeeRB2D.AddForce(new Vector2(0f, jumpForce));
        grounded = false;
    }

    private void TurnAround()
    {
        moveSpeed *= -1;
        Flip();
    }

    private void Flip()
    {
        if (facingLeft)
        {
            Vector3 theRotation = new Vector3(transform.localRotation.x, 180f, transform.localRotation.z);
            transform.rotation = Quaternion.Euler(theRotation);
        }
        else
        {
            Vector3 theRotation = new Vector3(transform.localRotation.x, 0, transform.localRotation.z);
            transform.rotation = Quaternion.Euler(theRotation);
        }
        facingLeft = !facingLeft;
    }
}
