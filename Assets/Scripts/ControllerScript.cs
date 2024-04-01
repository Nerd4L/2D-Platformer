using JetBrains.Annotations;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;

public class ControllerScript : MonoBehaviour
{
    private Rigidbody2D kirbyBody;

    public Vector2 moveInput;
    public bool jumpInput;

    public float jumpForce = 300f;                                               // Amount of force added when the player jumps.
    private bool facingRight = true;                                            // For determining which way the player is currently facing.
    const float groundedRadius = .3f;                                           // Distance of the overlap to determine if grounded
    private Vector3 velocity = Vector3.zero;

    public float blinkInterval = 5f;
    public float blinkTimer = 0f;

    private bool allowedToDoubleJump = false;

    [SerializeField] private Transform groundCheck;
    [SerializeField] private LayerMask whatIsGround;
    [SerializeField] private bool grounded;                                     // Whether or not the player is grounded
    [Range(0, .3f)][SerializeField] private float m_MovementSmoothing = .05f;   // How much to smooth out the movement

    [Header("Events")]
    [Space]

    public UnityEvent OnFallingEvent;
    public UnityEvent OnGroundedEvent;
    public UnityEvent OnBlink;

    [System.Serializable]
    public class BoolEvent : UnityEvent<bool> { }

    private void Awake()
    {
        kirbyBody = GetComponent<Rigidbody2D>();

        OnFallingEvent ??= new UnityEvent();
        OnGroundedEvent ??= new UnityEvent();
        OnBlink ??= new UnityEvent();

    }

    private void FixedUpdate()
    {
        grounded = false;

        // The player is grounded if a circlecast to the groundcheck position hits anything designated as ground
        // This can be done using layers instead but Sample Assets will not overwrite your project settings.
        Collider2D[] colliders = Physics2D.OverlapCircleAll(groundCheck.position, groundedRadius, whatIsGround);
        for (int i = 0; i < colliders.Length; i++)
        {
            if (colliders[i].gameObject != gameObject)
            {
                // Grounded
                grounded = true;
                OnGroundedEvent.Invoke();
                allowedToDoubleJump = true;

                // Blink
                blinkTimer += Time.deltaTime;
                float blinkValue = Mathf.Floor(blinkInterval * Random.value);
                if (blinkTimer > blinkValue)
                {
                    OnBlink.Invoke();
                    blinkTimer = 0;
                }

                // Tripping

            }
        }

        // Check if Falling
        if (kirbyBody.velocity.y < -2 && !grounded)
        {
            OnFallingEvent.Invoke();
            //wasFalling = true;
        }
    }

    public void Move(float move, bool jump)
    {
        // Move the character by finding the target velocity
        Vector3 targetVelocity = new Vector2(move * 10f, kirbyBody.velocity.y);
        // And then smoothing it out and applying it to the character
        kirbyBody.velocity = Vector3.SmoothDamp(kirbyBody.velocity, targetVelocity, ref velocity, m_MovementSmoothing);

        if (move > 0 && !facingRight)
        {
            // ... flip the player.
            Flip();
        }
        // Otherwise if the input is moving the player left and the player is facing right...
        else if (move < 0 && facingRight)
        {
            // ... flip the player.
            Flip();
        }

        // If the player should jump...
        if (grounded && jump || (!grounded && jump && allowedToDoubleJump))
        {
            Jump();
            allowedToDoubleJump = false;
        }
    }

    private void Flip()
    {
        // Switch the way the player is labelled as facing.
        facingRight = !facingRight;

        // Multiply the player's x local scale by -1.
        Vector3 theScale = transform.localScale;
        theScale.x *= -1;
        transform.localScale = theScale;
    }

    private void Jump()
    {
        // Add a vertical force to the player.
        grounded = false;
        kirbyBody.AddForce(new Vector2(0f, jumpForce));
    }
}
